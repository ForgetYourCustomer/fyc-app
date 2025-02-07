defmodule FycAppWeb.TradeLive.Show do
  use FycAppWeb, :live_view
  alias FycApp.Trade
  alias FycApp.Trade.MatchingEngine
  alias FycApp.Currencies

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      MatchingEngine.subscribe_to_market("BTC_USDT")
      Phoenix.PubSub.subscribe(FycApp.PubSub, "balance:#{socket.assigns.current_user.id}")
      Phoenix.PubSub.subscribe(FycApp.PubSub, "user_orders:#{socket.assigns.current_user.id}")
      Phoenix.PubSub.subscribe(FycApp.PubSub, "trades:BTC_USDT")
    end

    buy_form = to_form(%{"price" => "", "amount" => ""})
    sell_form = to_form(%{"price" => "", "amount" => ""})

    # Get trade history and format it for the chart
    trades =
      Trade.get_trade_history()
      |> Enum.map(fn trade ->
        %{
          price: trade.price |> Currencies.sunit_to_usdt() |> Decimal.to_float(),
          amount: trade.amount |> Currencies.satoshis_to_btc() |> Decimal.to_float(),
          executed_at: trade.inserted_at
        }
      end)

    IO.inspect(trades, label: "trades")

    socket =
      socket
      |> assign(:page_title, "Trade")
      |> assign(:buy_form, buy_form)
      |> assign(:sell_form, sell_form)
      |> assign(:buy_total, Decimal.new(0))
      |> assign(:sell_total, Decimal.new(0))
      |> assign(:current_price, 0)
      |> assign(:buy_orders, [])
      |> assign(:sell_orders, [])
      |> assign(:open_orders, Trade.list_user_orders(socket.assigns.current_user))
      |> assign(:trades, trades)
      |> assign_available_balances()
      |> assign_order_book()

    {:ok, socket}
  end

  @impl true
  def handle_event("place_buy_order", %{"price" => price, "amount" => amount}, socket) do
    current_user = socket.assigns.current_user

    # Convert stringified USDT price to Integer(cents) result has to be an integer
    price_cents = Currencies.usdt_to_sunit(price)
    # Convert stringified BTC amount to Integer(satoshis) result has to be an integer
    amount_satoshis = Currencies.btc_to_satoshis(amount)

    attrs = %{
      side: "buy",
      price: price_cents,
      amount: amount_satoshis,
      base_currency: "BTC",
      quote_currency: "USDT"
    }

    case Trade.create_order(current_user, attrs) do
      {:ok} ->
        socket =
          socket
          |> put_flash(:info, "Buy order placed successfully")
          |> assign(:buy_form, to_form(%{"price" => "", "amount" => ""}))

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :buy_form, changeset)}

      {:error, :insufficient_balance} ->
        socket =
          socket
          |> put_flash(:error, "Insufficient balance")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("place_sell_order", %{"price" => price, "amount" => amount}, socket) do
    current_user = socket.assigns.current_user

    # Convert stringified USDT price to Integer(cents) result has to be an integer
    price_cents = Currencies.usdt_to_sunit(price)
    # Convert stringified BTC amount to Integer(satoshis) result has to be an integer
    amount_satoshis = Currencies.btc_to_satoshis(amount)

    attrs = %{
      side: "sell",
      price: price_cents,
      amount: amount_satoshis,
      base_currency: "BTC",
      quote_currency: "USDT"
    }

    case Trade.create_order(current_user, attrs) do
      {:ok} ->
        socket =
          socket
          |> put_flash(:info, "Sell order placed successfully")
          |> assign(:sell_form, to_form(%{"price" => "", "amount" => ""}))

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :sell_form, changeset)}

      {:error, :insufficient_balance} ->
        socket =
          socket
          |> put_flash(:error, "Insufficient balance")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_order", %{"id" => order_id}, socket) do
    current_user = socket.assigns.current_user

    case Trade.cancel_order(current_user, order_id) do
      {:ok, _order} ->
        {:noreply, put_flash(socket, :info, "Order cancelled successfully")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to cancel order")}
    end
  end

  def handle_event("buy_form_changed", %{"price" => price, "amount" => amount}, socket) do
    # get amount and price from params
    total =
      with {p, _} <- Decimal.parse(price),
           {a, _} <- Decimal.parse(amount) do
        Decimal.mult(p, a)
      else
        _ -> Decimal.new(0)
      end

    {:noreply, assign(socket, :buy_total, total)}
  end

  def handle_event("sell_form_changed", %{"price" => price, "amount" => amount}, socket) do
    # handle regular form change
    total =
      with {p, _} <- Decimal.parse(price),
           {a, _} <- Decimal.parse(amount) do
        Decimal.mult(p, a)
      else
        _ -> Decimal.new(0)
      end

    {:noreply, assign(socket, :sell_total, total)}
  end

  @impl true
  def handle_info({:order_book_updated, order_book}, socket) do
    IO.inspect(order_book, label: "order book updated")

    socket =
      socket
      |> assign(:buy_orders, order_book.buy_orders)
      |> assign(:sell_orders, order_book.sell_orders)
      |> maybe_update_current_price(order_book)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:trade_executed, %{price: price, amount: amount} = _trade}, socket) do
    trade_data = %{
      price: price |> Currencies.sunit_to_usdt() |> Decimal.to_float(),
      amount: amount |> Currencies.satoshis_to_btc() |> Decimal.to_float(),
      executed_at: DateTime.utc_now()
    }

    IO.inspect(trade_data, label: "trade data")

    # Keep last 100 trades
    trades = [trade_data | socket.assigns.trades] |> Enum.take(100)
    IO.inspect(trades, label: "updated trades")

    {:noreply, assign(socket, :trades, trades)}
  end

  @impl true
  def handle_info({:balance_updated, currency}, socket) do
    # Update both BTC and USDT available balances
    socket = assign_available_balances(socket)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:order_created, order}, socket) do
    socket =
      socket
      |> assign(:open_orders, [order | socket.assigns.open_orders])
      |> assign_available_balance(order)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:order_cancelled, order}, socket) do
    socket =
      socket
      |> assign(:open_orders, Enum.reject(socket.assigns.open_orders, &(&1.id == order.id)))
      |> assign_available_balance(order)

    {:noreply, socket}
  end

  defp assign_order_book(socket) do
    # Get initial order book state
    current_user = socket.assigns.current_user

    socket
    # Initially empty, will be updated via PubSub
    |> assign(:buy_orders, [])
    # Initially empty, will be updated via PubSub
    |> assign(:sell_orders, [])

    # |> assign(:open_orders, Trade.list_open_orders(current_user))
  end

  defp maybe_update_current_price(socket, %{sell_orders: [%{price: price} | _]}) do
    assign(socket, :current_price, price)
  end

  defp maybe_update_current_price(socket, %{buy_orders: [%{price: price} | _]}) do
    assign(socket, :current_price, price)
  end

  defp maybe_update_current_price(socket, _), do: socket

  defp assign_available_balances(socket) do
    balances =
      Currencies.supported_currencies()
      |> Map.new(fn currency ->
        {currency, Trade.available_balance(socket.assigns.current_user.id, currency)}
      end)

    assign(socket, :available_balances, balances)
  end

  defp assign_available_balance(socket, order) do
    currency =
      if order.side == "buy", do: order.quote_currency, else: order.base_currency

    updated_balances =
      Map.update(
        socket.assigns.available_balances || %{},
        currency,
        Trade.available_balance(socket.assigns.current_user.id, currency),
        fn _old -> Trade.available_balance(socket.assigns.current_user.id, currency) end
      )

    assign(socket, :available_balances, updated_balances)
  end

  defp assign_balances(socket) do
    balances =
      Currencies.supported_currencies()
      |> Map.new(fn currency ->
        {currency, Trade.available_balance(socket.assigns.current_user.id, currency)}
      end)

    assign(socket, :available_balances, balances)
  end
end
