defmodule FycAppWeb.TradeLive.Show do
  use FycAppWeb, :live_view
  alias FycApp.Trade
  alias FycApp.Trade.MatchingEngine

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      MatchingEngine.subscribe_to_market("BTC_USDT")
    end

    buy_form = to_form(%{"price" => "", "amount" => ""})
    sell_form = to_form(%{"price" => "", "amount" => ""})

    socket =
      socket
      |> assign(:page_title, "Trade")
      |> assign(:buy_form, buy_form)
      |> assign(:sell_form, sell_form)
      |> assign(:buy_total, Decimal.new(0))
      |> assign(:sell_total, Decimal.new(0))
      |> assign(:current_price, Decimal.new(0))
      |> assign(:buy_orders, [])
      |> assign(:sell_orders, [])
      |> assign(:open_orders, [])
      |> assign_order_book()

    {:ok, socket}
  end

  @impl true
  def handle_event("place_buy_order", %{"price" => price, "amount" => amount}, socket) do
    current_user = socket.assigns.current_user

    attrs = %{
      "side" => "buy",
      "price" => price,
      "amount" => amount,
      "base_currency" => "BTC",
      "quote_currency" => "USDT"
    }

    case Trade.create_order(current_user, attrs) do
      {:ok, _order} ->
        socket =
          socket
          |> put_flash(:info, "Buy order placed successfully")
          |> assign(:buy_form, to_form(%{"price" => "", "amount" => ""}))
          |> assign(:buy_total, Decimal.new(0))

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :buy_form, to_form(changeset))}

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

    attrs = %{
      "side" => "sell",
      "price" => price,
      "amount" => amount,
      "base_currency" => "BTC",
      "quote_currency" => "USDT"
    }

    case Trade.create_order(current_user, attrs) do
      {:ok, _order} ->
        socket =
          socket
          |> put_flash(:info, "Sell order placed successfully")
          |> assign(:sell_form, to_form(%{"price" => "", "amount" => ""}))
          |> assign(:sell_total, Decimal.new(0))

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :sell_form, to_form(changeset))}

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

    case Trade.cancel_order(order_id, current_user) do
      {:ok, _order} ->
        {:noreply, put_flash(socket, :info, "Order cancelled successfully")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to cancel order")}
    end
  end

  @impl true
  def handle_event("validate_buy", %{"price" => price, "amount" => amount}, socket) do
    total =
      case {Decimal.parse(price), Decimal.parse(amount)} do
        {{:ok, p}, {:ok, a}} -> Decimal.mult(p, a)
        _ -> Decimal.new(0)
      end

    {:noreply, assign(socket, :buy_total, total)}
  end

  @impl true
  def handle_event("validate_sell", %{"price" => price, "amount" => amount}, socket) do
    total =
      case {Decimal.parse(price), Decimal.parse(amount)} do
        {{:ok, p}, {:ok, a}} -> Decimal.mult(p, a)
        _ -> Decimal.new(0)
      end

    {:noreply, assign(socket, :sell_total, total)}
  end

  @impl true
  def handle_info({:order_book_updated, order_book}, socket) do
    socket =
      socket
      |> assign(:buy_orders, order_book.buy_orders)
      |> assign(:sell_orders, order_book.sell_orders)
      |> maybe_update_current_price(order_book)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:trade_executed, _trade}, socket) do
    {:noreply, assign_order_book(socket)}
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
end
