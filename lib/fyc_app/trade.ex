defmodule FycApp.Trade do
  @moduledoc """
  The Trade context.
  """

  import Ecto.Query, warn: false
  alias FycApp.Repo
  alias FycApp.Trade.{Order, TradeExecution}
  alias FycApp.Wallets
  alias Ecto.Multi

  @doc """
  Creates a new order with funds validation.

  ## Parameters
    - user: The user creating the order
    - attrs: Order attributes

  ## Examples
      iex> create_order(user, %{
        order_type: "limit",
        side: "buy",
        base_currency: "BTC",
        quote_currency: "USDT",
        price: "50000.00",
        amount: "1.5"
      })
      {:ok, %Order{}}
  """
  def create_order(user, attrs) do
    # Generate a unique client_order_id if not provided
    attrs = Map.put_new(attrs, :client_order_id, generate_client_order_id())
    attrs = Map.put(attrs, :user_id, user.id)

    Multi.new()
    |> Multi.run(:validate_balance, fn repo, _changes ->
      validate_balance(user, attrs)
    end)
    |> Multi.run(:lock_balance, fn repo, _changes ->
      lock_balance(user, attrs)
    end)
    |> Multi.insert(:order, fn _changes ->
      Order.changeset(%Order{}, attrs)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{order: order}} = result ->
        # Broadcast the new order to the matching engine
        broadcast_new_order(order)
        result
      
      {:error, _failed_operation, changeset, _changes} ->
        {:error, changeset}
    end
  end

  @doc """
  Lists orders for a specific market (trading pair).

  ## Examples
      iex> list_market_orders("BTC", "USDT")
      %{
        buy_orders: [%Order{}],
        sell_orders: [%Order{}]
      }
  """
  def list_market_orders(base_currency, quote_currency) do
    base_query = from(o in Order,
      where: o.base_currency == ^base_currency and
             o.quote_currency == ^quote_currency and
             o.status in ["pending", "partial"],
      order_by: [desc: o.inserted_at]
    )

    buy_orders =
      from(o in base_query,
        where: o.side == "buy",
        order_by: [desc: o.price]
      )
      |> Repo.all()

    sell_orders =
      from(o in base_query,
        where: o.side == "sell",
        order_by: [asc: o.price]
      )
      |> Repo.all()

    %{
      buy_orders: buy_orders,
      sell_orders: sell_orders
    }
  end

  @doc """
  Lists open orders for a specific user.

  ## Examples
      iex> list_user_orders(user)
      [%Order{}]
  """
  def list_user_orders(user) do
    Order
    |> where([o], o.user_id == ^user.id)
    |> where([o], o.status in ["pending", "partial"])
    |> order_by([o], [desc: o.inserted_at])
    |> Repo.all()
  end

  @doc """
  Cancels an order.

  ## Examples
      iex> cancel_order(order)
      {:ok, %Order{}}
  """
  def cancel_order(%Order{} = order) do
    Multi.new()
    |> Multi.update(:order, Order.changeset(order, %{status: "cancelled"}))
    |> Multi.run(:unlock_balance, fn repo, _changes ->
      unlock_balance(order)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{order: order}} = result ->
        broadcast_cancel_order(order)
        result
      
      {:error, _failed_operation, changeset, _changes} ->
        {:error, changeset}
    end
  end

  @doc """
  Executes a trade between a buy order and a sell order.
  This function handles:
  1. Updating order filled amounts
  2. Creating trade record
  3. Updating user balances
  4. Unlocking appropriate amounts
  """
  def execute_trade(%{buy_order: buy_order, sell_order: sell_order, amount: amount, price: price}) do
    Multi.new()
    |> Multi.run(:lock_orders, fn repo, _ ->
      # Lock both orders to prevent concurrent modifications
      buy_order = repo.one(from o in Order,
        where: o.id == ^buy_order.id,
        lock: "FOR UPDATE"
      )
      sell_order = repo.one(from o in Order,
        where: o.id == ^sell_order.id,
        lock: "FOR UPDATE"
      )

      {:ok, %{buy_order: buy_order, sell_order: sell_order}}
    end)
    |> Multi.run(:validate_orders, fn _repo, %{lock_orders: %{buy_order: buy_order, sell_order: sell_order}} ->
      with :ok <- validate_order_status(buy_order),
           :ok <- validate_order_status(sell_order),
           :ok <- validate_remaining_amount(buy_order, amount),
           :ok <- validate_remaining_amount(sell_order, amount) do
        {:ok, :valid}
      end
    end)
    |> Multi.insert(:trade, fn _ ->
      %TradeExecution{
        buy_order_id: buy_order.id,
        sell_order_id: sell_order.id,
        price: price,
        amount: amount,
        total: Decimal.mult(price, amount)
      }
    end)
    |> Multi.run(:update_orders, fn repo, %{trade: trade} ->
      # Update filled amounts and status for both orders
      update_order_fills(repo, buy_order, sell_order, amount)
    end)
    |> Multi.run(:update_balances, fn repo, %{trade: trade} ->
      # Transfer base currency from seller to buyer
      # Transfer quote currency from buyer to seller
      update_balances(repo, buy_order, sell_order, amount, price)
    end)
    |> Repo.transaction()
  end

  # Private helper functions for execute_trade

  defp validate_order_status(order) do
    if order.status in ["pending", "partial"] do
      :ok
    else
      {:error, "Order #{order.id} is #{order.status}"}
    end
  end

  defp validate_remaining_amount(order, amount) do
    remaining = Decimal.sub(order.amount, order.filled_amount)
    if Decimal.compare(remaining, amount) != :lt do
      :ok
    else
      {:error, "Insufficient remaining amount in order #{order.id}"}
    end
  end

  defp update_order_fills(repo, buy_order, sell_order, amount) do
    # Update buy order
    {buy_status, buy_filled} = get_new_status_and_filled(buy_order, amount)
    {:ok, updated_buy} = update_order(buy_order, %{
      status: buy_status,
      filled_amount: buy_filled
    })

    # Update sell order
    {sell_status, sell_filled} = get_new_status_and_filled(sell_order, amount)
    {:ok, updated_sell} = update_order(sell_order, %{
      status: sell_status,
      filled_amount: sell_filled
    })

    {:ok, %{buy_order: updated_buy, sell_order: updated_sell}}
  end

  defp get_new_status_and_filled(order, amount) do
    new_filled = Decimal.add(order.filled_amount, amount)
    status = if Decimal.compare(new_filled, order.amount) == :eq do
      "filled"
    else
      "partial"
    end
    {status, new_filled}
  end

  defp update_balances(repo, buy_order, sell_order, amount, price) do
    quote_amount = Decimal.mult(amount, price)
    
    with {:ok, _} <- transfer_balance(buy_order.user_id, sell_order.user_id, 
                                    buy_order.quote_currency, quote_amount),
         {:ok, _} <- transfer_balance(sell_order.user_id, buy_order.user_id, 
                                    buy_order.base_currency, amount) do
      {:ok, :balances_updated}
    end
  end

  defp transfer_balance(from_user_id, to_user_id, currency, amount) do
    Multi.new()
    |> Multi.run(:debit, fn repo, _ ->
      Wallets.debit_balance(from_user_id, currency, amount)
    end)
    |> Multi.run(:credit, fn repo, _ ->
      Wallets.credit_balance(to_user_id, currency, amount)
    end)
    |> Repo.transaction()
  end

  # Private functions

  defp validate_balance(user, %{side: "buy", quote_currency: currency, price: price, amount: amount} = attrs) do
    required_amount = Decimal.mult(price, amount)
    case Wallets.get_balance(user.id, currency) do
      nil -> 
        {:error, "No balance found for #{currency}"}
      balance ->
        if Decimal.compare(balance.amount, required_amount) == :lt do
          {:error, "Insufficient #{currency} balance"}
        else
          {:ok, balance}
        end
    end
  end

  defp validate_balance(user, %{side: "sell", base_currency: currency, amount: amount} = attrs) do
    case Wallets.get_balance(user.id, currency) do
      nil -> 
        {:error, "No balance found for #{currency}"}
      balance ->
        if Decimal.compare(balance.amount, amount) == :lt do
          {:error, "Insufficient #{currency} balance"}
        else
          {:ok, balance}
        end
    end
  end

  defp lock_balance(user, %{side: "buy", quote_currency: currency, price: price, amount: amount} = attrs) do
    required_amount = Decimal.mult(price, amount)
    
    # Get current balance and any existing locks
    balance = Wallets.get_balance!(user.id, currency)
    locked_amount = get_total_locked_amount(user.id, currency)
    available_amount = Decimal.sub(balance.amount, locked_amount)

    if Decimal.compare(available_amount, required_amount) == :lt do
      {:error, "Insufficient available #{currency} balance"}
    else
      create_locked_balance(%{
        user_id: user.id,
        currency: currency,
        amount: required_amount
      })
    end
  end

  defp lock_balance(user, %{side: "sell", base_currency: currency, amount: amount} = attrs) do
    # Get current balance and any existing locks
    balance = Wallets.get_balance!(user.id, currency)
    locked_amount = get_total_locked_amount(user.id, currency)
    available_amount = Decimal.sub(balance.amount, locked_amount)

    if Decimal.compare(available_amount, amount) == :lt do
      {:error, "Insufficient available #{currency} balance"}
    else
      create_locked_balance(%{
        user_id: user.id,
        currency: currency,
        amount: amount
      })
    end
  end

  defp unlock_balance(%Order{} = order) do
    case order.side do
      "buy" ->
        currency = order.quote_currency
        amount = Decimal.mult(order.price, Decimal.sub(order.amount, order.filled_amount))
        unlock_amount(order.user_id, order.id, currency, amount)
      "sell" ->
        currency = order.base_currency
        amount = Decimal.sub(order.amount, order.filled_amount)
        unlock_amount(order.user_id, order.id, currency, amount)
    end
  end

  defp unlock_amount(user_id, order_id, currency, amount) do
    query = from lb in LockedBalance,
      where: lb.user_id == ^user_id and
             lb.currency == ^currency and
             lb.order_id == ^order_id

    case Repo.one(query) do
      nil -> {:error, :locked_balance_not_found}
      locked_balance ->
        Multi.new()
        |> Multi.delete(:delete_locked_balance, locked_balance)
        |> Multi.run(:credit_balance, fn _repo, _ ->
          Wallets.credit_balance(user_id, currency, amount)
        end)
        |> Repo.transaction()
    end
  end

  defp get_total_locked_amount(user_id, currency) do
    LockedBalance
    |> where([lb], lb.user_id == ^user_id and lb.currency == ^currency)
    |> select([lb], sum(lb.amount))
    |> Repo.one()
    |> case do
      nil -> Decimal.new(0)
      amount -> amount
    end
  end

  defp generate_client_order_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16()
  end

  defp broadcast_new_order(order) do
    Phoenix.PubSub.broadcast(
      FycApp.PubSub,
      "orders:#{order.base_currency}_#{order.quote_currency}",
      {:new_order, order}
    )
  end

  defp broadcast_cancel_order(order) do
    Phoenix.PubSub.broadcast(
      FycApp.PubSub,
      "orders:#{order.base_currency}_#{order.quote_currency}",
      {:cancel_order, order}
    )
  end

  @doc """
  Returns the list of orders.

  ## Examples

      iex> list_orders()
      [%Order{}, ...]

  """
  def list_orders do
    Repo.all(Order)
  end

  @doc """
  Gets a single order.

  Raises `Ecto.NoResultsError` if the Order does not exist.

  ## Examples

      iex> get_order!(123)
      %Order{}

      iex> get_order!(456)
      ** (Ecto.NoResultsError)

  """
  def get_order!(id), do: Repo.get!(Order, id)

  @doc """
  Creates a order.

  ## Examples

      iex> create_order(%{field: value})
      {:ok, %Order{}}

      iex> create_order(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_order(attrs \\ %{}) do
    %Order{}
    |> Order.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a order.

  ## Examples

      iex> update_order(order, %{field: new_value})
      {:ok, %Order{}}

      iex> update_order(order, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_order(%Order{} = order, attrs) do
    order
    |> Order.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a order.

  ## Examples

      iex> delete_order(order)
      {:ok, %Order{}}

      iex> delete_order(order)
      {:error, %Ecto.Changeset{}}

  """
  def delete_order(%Order{} = order) do
    Repo.delete(order)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking order changes.

  ## Examples

      iex> change_order(order)
      %Ecto.Changeset{data: %Order{}}

  """
  def change_order(%Order{} = order, attrs \\ %{}) do
    Order.changeset(order, attrs)
  end

  alias FycApp.Trade.LockedBalance

  @doc """
  Returns the list of locked_balances.

  ## Examples

      iex> list_locked_balances()
      [%LockedBalance{}, ...]

  """
  def list_locked_balances do
    Repo.all(LockedBalance)
  end

  @doc """
  Gets a single locked_balance.

  Raises `Ecto.NoResultsError` if the Locked balance does not exist.

  ## Examples

      iex> get_locked_balance!(123)
      %LockedBalance{}

      iex> get_locked_balance!(456)
      ** (Ecto.NoResultsError)

  """
  def get_locked_balance!(id), do: Repo.get!(LockedBalance, id)

  @doc """
  Creates a locked_balance.

  ## Examples

      iex> create_locked_balance(%{field: value})
      {:ok, %LockedBalance{}}

      iex> create_locked_balance(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_locked_balance(attrs \\ %{}) do
    %LockedBalance{}
    |> LockedBalance.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a locked_balance.

  ## Examples

      iex> update_locked_balance(locked_balance, %{field: new_value})
      {:ok, %LockedBalance{}}

      iex> update_locked_balance(locked_balance, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_locked_balance(%LockedBalance{} = locked_balance, attrs) do
    locked_balance
    |> LockedBalance.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a locked_balance.

  ## Examples

      iex> delete_locked_balance(locked_balance)
      {:ok, %LockedBalance{}}

      iex> delete_locked_balance(locked_balance)
      {:error, %Ecto.Changeset{}}

  """
  def delete_locked_balance(%LockedBalance{} = locked_balance) do
    Repo.delete(locked_balance)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking locked_balance changes.

  ## Examples

      iex> change_locked_balance(locked_balance)
      %Ecto.Changeset{data: %LockedBalance{}}

  """
  def change_locked_balance(%LockedBalance{} = locked_balance, attrs \\ %{}) do
    LockedBalance.changeset(locked_balance, attrs)
  end

  alias FycApp.Trade.TradeExecution

  @doc """
  Returns the list of trades.

  ## Examples

      iex> list_trades()
      [%TradeExecution{}, ...]

  """
  def list_trades do
    Repo.all(TradeExecution)
  end

  @doc """
  Gets a single trade_execution.

  Raises `Ecto.NoResultsError` if the Trade execution does not exist.

  ## Examples

      iex> get_trade_execution!(123)
      %TradeExecution{}

      iex> get_trade_execution!(456)
      ** (Ecto.NoResultsError)

  """
  def get_trade_execution!(id), do: Repo.get!(TradeExecution, id)

  @doc """
  Creates a trade_execution.

  ## Examples

      iex> create_trade_execution(%{field: value})
      {:ok, %TradeExecution{}}

      iex> create_trade_execution(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_trade_execution(attrs \\ %{}) do
    %TradeExecution{}
    |> TradeExecution.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a trade_execution.

  ## Examples

      iex> update_trade_execution(trade_execution, %{field: new_value})
      {:ok, %TradeExecution{}}

      iex> update_trade_execution(trade_execution, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_trade_execution(%TradeExecution{} = trade_execution, attrs) do
    trade_execution
    |> TradeExecution.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a trade_execution.

  ## Examples

      iex> delete_trade_execution(trade_execution)
      {:ok, %TradeExecution{}}

      iex> delete_trade_execution(trade_execution)
      {:error, %Ecto.Changeset{}}

  """
  def delete_trade_execution(%TradeExecution{} = trade_execution) do
    Repo.delete(trade_execution)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking trade_execution changes.

  ## Examples

      iex> change_trade_execution(trade_execution)
      %Ecto.Changeset{data: %TradeExecution{}}

  """
  def change_trade_execution(%TradeExecution{} = trade_execution, attrs \\ %{}) do
    TradeExecution.changeset(trade_execution, attrs)
  end
end
