defmodule FycApp.Wallets do
  @moduledoc """
  The Wallets context.
  """

  import Ecto.Query, warn: false
  alias FycApp.Repo
  alias Ecto.Multi

  alias FycApp.Wallets.{Wallet, Balance, Deposit, DepositHistory, Action}
  alias FycApp.Currencies

  @doc """
  Returns the list of wallets.

  ## Examples

      iex> list_wallets()
      [%Wallet{}, ...]

  """
  def list_wallets do
    Repo.all(Wallet)
  end

  @doc """
  Gets a single wallet.

  Raises `Ecto.NoResultsError` if the Wallet does not exist.

  ## Examples

      iex> get_wallet!(123)
      %Wallet{}

      iex> get_wallet!(456)
      ** (Ecto.NoResultsError)

  """
  def get_wallet!(id), do: Repo.get!(Wallet, id)

  @doc """
  Gets a user's wallet.

  Creates a new wallet if one doesn't exist.

  ## Examples

      iex> get_user_wallet(123)
      %Wallet{}

      iex> get_user_wallet(456)
      nil

  """
  def get_user_wallet(%FycApp.Accounts.User{id: user_id}), do: get_user_wallet(user_id)

  def get_user_wallet(user_id) when is_binary(user_id) do
    wallet =
      Wallet
      |> where([w], w.user_id == ^user_id)
      |> preload(balances: :deposits)
      |> Repo.one()

    case wallet do
      nil ->
        {:ok, wallet} = create_wallet(%{user_id: user_id})
        %{wallet | balances: []}

      %Wallet{balances: nil} = w ->
        %{w | balances: []}

      wallet ->
        wallet
    end
  end

  @doc """
  Creates a wallet.

  ## Examples

      iex> create_wallet(%{field: value})
      {:ok, %Wallet{}}

      iex> create_wallet(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_wallet(attrs \\ %{}) do
    %Wallet{}
    |> Wallet.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a wallet.

  ## Examples

      iex> update_wallet(wallet, %{field: new_value})
      {:ok, %Wallet{}}

      iex> update_wallet(wallet, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_wallet(%Wallet{} = wallet, attrs) do
    wallet
    |> Wallet.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a wallet.

  ## Examples

      iex> delete_wallet(wallet)
      {:ok, %Wallet{}}

      iex> delete_wallet(wallet)
      {:error, %Ecto.Changeset{}}

  """
  def delete_wallet(%Wallet{} = wallet) do
    Repo.delete(wallet)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking wallet changes.

  ## Examples

      iex> change_wallet(wallet)
      %Ecto.Changeset{data: %Wallet{}}

  """
  def change_wallet(%Wallet{} = wallet, attrs \\ %{}) do
    Wallet.changeset(wallet, attrs)
  end

  @doc """
  Ensures all supported currencies have balances created for the wallet.
  Returns the wallet with all necessary balances created and preloaded.
  """
  def ensure_balances_created(%Wallet{} = wallet) do
    # Get existing currencies for this wallet
    existing_currencies =
      wallet.balances
      |> Enum.map(& &1.currency)
      |> MapSet.new()

    # Find which currencies need to be created
    currencies_to_create =
      Currencies.supported_currencies()
      |> Enum.reject(&MapSet.member?(existing_currencies, &1))

    case currencies_to_create do
      [] ->
        # No new balances needed
        wallet

      currencies ->
        # Create balances for missing currencies using changesets
        balances =
          Enum.map(currencies, fn currency ->
            %Balance{}
            |> Balance.changeset(%{
              currency: currency,
              amount: 0,
              wallet_id: wallet.id
            })
            |> Repo.insert!()
          end)

        # Reload wallet with all balances
        Repo.preload(wallet, balances: :deposits)
    end
  end

  @doc """
  Process an action on a wallet (deposit, withdrawal, etc.)
  """
  def process_action(wallet, action_params, meta \\ %{})

  def process_action(%Wallet{} = wallet, %{action_type: "deposit"} = action_params, meta) do
    with {:ok, action_changeset} <- validate_action(action_params, wallet) do
      tx_id =
        case action_params.in_currency do
          "BTC" -> meta["tx_id"]
          "USDT" -> meta["tx_id"] <> "_" <> to_string(meta["index"])
        end

      Multi.new()
      # Ensure transaction doesn't already added on DepositHistory
      |> Multi.run(:check_tx, fn repo, _changes ->
        case repo.one(from h in DepositHistory, where: h.tx_id == ^tx_id) do
          nil -> {:ok, nil}
          _history -> {:error, :transaction_exists}
        end
      end)
      # Insert action
      |> Multi.insert(:action, action_changeset)
      # Update balance according to deposit action
      |> Multi.run(:balance, fn repo, _changes ->
        balance =
          repo.one!(
            from b in Balance,
              where: b.wallet_id == ^wallet.id and b.currency == ^action_params.in_currency
          )

        balance_changeset =
          case action_params.in_currency do
            "BTC" -> Balance.deposit_btc_balance_changeset(balance, action_params.in_amount)
            "USDT" -> Balance.deposit_usdt_balance_changeset(balance, action_params.in_amount)
          end

        repo.update(balance_changeset)
      end)
      # Insert deposit history
      |> Multi.insert(:deposit_history, fn %{balance: balance} ->
        DepositHistory.changeset(%DepositHistory{}, %{
          balance_id: balance.id,
          deposit_address: meta["deposit_address"],
          amount: action_params.in_amount,
          tx_id: tx_id
        })
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{balance: balance} = result} ->
          # Broadcast only the changed balance
          Phoenix.PubSub.broadcast(
            FycApp.PubSub,
            "wallet:#{wallet.id}",
            {:balance_updated, balance.currency, balance.amount}
          )

          {:ok, result}

        {:error, :check_tx, :transaction_exists, _} ->
          {:error, :check_tx, :transaction_exists, nil}

        {:error, :deposit_history,
         %Ecto.Changeset{
           errors: [
             tx_id:
               {_, [constraint: :unique, constraint_name: "deposit_history_tx_id_unique_index"]}
           ]
         }, _} ->
          {:error, :check_tx, :transaction_exists, nil}

        {:error, operation, value, _changes} ->
          {:error, operation, value}
      end
    end
  end

  def process_action(_, _, _), do: {:error, :invalid_action}

  defp validate_action(params, wallet) do
    case Action.changeset(%Action{}, Map.put(params, :wallet_id, wallet.id)) do
      %{valid?: true} = changeset -> {:ok, changeset}
      changeset -> {:error, changeset}
    end
  end

  @doc """
  Process a transaction by creating a deposit action and updating the balance.

  Returns:
  - {:ok, %{deposit_history: history, balance: balance}} if successful
  - {:error, :deposit_not_found} if address not found
  - {:error, :transaction_exists} if tx_id already exists
  - {:error, changeset} if there's a validation error
  """
  def process_deposit(
        "BTC",
        %{"deposit" => {"deposits", deposits}} = _tx_details
      )
      when is_list(deposits) do
    # Process each deposit in the list
    results =
      Enum.map(deposits, fn [address, amount, tx_id] ->
        process_single_deposit("BTC", %{"deposit" => [address, amount, tx_id]})
      end)

    # Check if any deposit failed
    case Enum.find(results, &(elem(&1, 0) == :error)) do
      nil ->
        # All deposits successful, return the last one's result
        List.last(results)

      error ->
        # Return the first error encountered
        error
    end
  end

  def process_deposit(
        "BTC",
        %{"deposit" => [_address, _amount, _tx_id]} = tx_details
      ) do
    process_single_deposit("BTC", tx_details)
  end

  defp process_single_deposit(
         "BTC",
         %{"deposit" => [address, amount, tx_id]} = _tx_details
       ) do
    # Convert amount to integer (satoshis/smallest unit)

    # Find the deposit and preload its wallet
    case Repo.one(
           from d in Deposit,
             join: b in assoc(d, :balance),
             where: d.address == ^address and d.is_active == true and b.currency == "BTC",
             preload: [balance: :wallet]
         ) do
      nil ->
        {:error, :deposit_not_found}

      deposit ->
        process_action(
          deposit.balance.wallet,
          %{
            action_type: "deposit",
            in_amount: amount,
            in_currency: "BTC",
            out_amount: 0
          },
          %{
            "tx_id" => tx_id,
            "deposit_address" => address
          }
        )
        |> case do
          {:ok, %{balance: balance, action: action, deposit_history: deposit_history}} ->
            {:ok, %{balance: balance, action: action, deposit_history: deposit_history}}

          error ->
            error
        end
    end
  end

  # (address, amount, block_number, hash, index)
  def process_deposit(
        "USDT",
        %{"deposit" => [address, amount, block_number, tx_id, index]} = _tx_details
      ) do
    # Find the deposit and preload its wallet and ensure currency matches
    case Repo.one(
           from d in Deposit,
             join: b in assoc(d, :balance),
             where: d.address == ^address and d.is_active == true and b.currency == "USDT",
             preload: [balance: :wallet]
         ) do
      nil ->
        {:error, :deposit_not_found}

      deposit ->
        process_action(
          deposit.balance.wallet,
          %{
            action_type: "deposit",
            in_amount: amount,
            in_currency: "USDT",
            out_amount: 0
          },
          %{
            "tx_id" => tx_id,
            "block_number" => block_number,
            "index" => index,
            "deposit_address" => address
          }
        )
        |> case do
          {:ok, %{balance: balance, action: action, deposit_history: deposit_history}} ->
            {:ok, %{balance: balance, action: action, deposit_history: deposit_history}}

          error ->
            error
        end
    end
  end

  def process_transaction(_), do: {:error, :invalid_transaction_format}

  @doc """
  Gets a user's balance for a specific currency.
  Returns {:ok, balance} if found, {:error, :not_found} otherwise.
  """
  def get_balance(user_id, currency) do
    query =
      from b in Balance,
        join: w in Wallet,
        on: b.wallet_id == w.id,
        where: w.user_id == ^user_id and b.currency == ^currency,
        select: b

    case Repo.one(query) do
      nil -> {:error, :not_found}
      balance -> {:ok, balance}
    end
  end

  @doc """
  Gets a user's balance for a specific currency.
  Raises Ecto.NoResultsError if not found.
  """
  def get_balance!(user_id, currency) do
    query =
      from b in Balance,
        join: w in Wallet,
        on: b.wallet_id == w.id,
        where: w.user_id == ^user_id and b.currency == ^currency,
        select: b

    Repo.one!(query)
  end

  @doc """
  Credits (increases) a user's balance for a specific currency.
  """
  def credit_balance(user_id, currency, amount) do
    with {:ok, balance} <- get_balance(user_id, currency) do
      balance
      |> Balance.changeset(%{
        amount: balance.amount + amount
      })
      |> Repo.update()
    end
  end

  @doc """
  Debits (decreases) a user's balance for a specific currency.
  Returns error if insufficient funds.
  """
  def debit_balance(user_id, currency, amount) do
    with {:ok, balance} <- get_balance(user_id, currency),
         :ok <- check_sufficient_funds(balance, amount) do
      balance
      |> Balance.changeset(%{
        amount: balance.amount - amount
      })
      |> Repo.update()
    end
  end

  # Private Functions

  defp check_sufficient_funds(balance, amount) do
    if balance.amount >= amount do
      :ok
    else
      {:error, :insufficient_funds}
    end
  end
end
