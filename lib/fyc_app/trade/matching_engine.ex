defmodule FycApp.Trade.MatchingEngine do
  use GenServer
  require Logger
  alias FycApp.Trade.{Order, PriorityQueue}
  alias FycApp.Trade
  alias Phoenix.PubSub

  @pubsub FycApp.PubSub

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def add_order(%Order{} = order) do
    GenServer.cast(__MODULE__, {:add_order, order})
  end

  def cancel_order(%Order{} = order) do
    GenServer.cast(__MODULE__, {:cancel_order, order})
  end

  def subscribe_to_market(market) do
    PubSub.subscribe(@pubsub, "orderbook:#{market}")
  end

  def unsubscribe_from_market(market) do
    PubSub.unsubscribe(@pubsub, "orderbook:#{market}")
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # State structure:
    # %{
    #   "BTC_USDT" => %{
    #     buy_orders: priority_queue,  # Sorted by highest price first
    #     sell_orders: priority_queue  # Sorted by lowest price first
    #   }
    # }
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:add_order, order}, state) do
    market = "#{order.base_currency}_#{order.quote_currency}"
    market_state = Map.get(state, market, %{
      buy_orders: PriorityQueue.new(),
      sell_orders: PriorityQueue.new()
    })

    # Add order to the appropriate queue
    market_state = add_to_queue(market_state, order)
    
    # Try to match orders
    {market_state, matches} = match_orders(market_state)
    
    # Execute matches if any
    execute_matches(matches)

    # Broadcast updated order book
    broadcast_order_book(market, market_state)

    # Update state with new market state
    {:noreply, Map.put(state, market, market_state)}
  end

  @impl true
  def handle_cast({:cancel_order, order}, state) do
    market = "#{order.base_currency}_#{order.quote_currency}"
    
    case Map.get(state, market) do
      nil -> 
        {:noreply, state}
      
      market_state ->
        # Remove order from appropriate queue
        market_state = remove_from_queue(market_state, order)

        # Broadcast updated order book
        broadcast_order_book(market, market_state)

        {:noreply, Map.put(state, market, market_state)}
    end
  end

  # Private Functions

  defp add_to_queue(market_state, %Order{side: "buy"} = order) do
    buy_orders = PriorityQueue.insert_buy(market_state.buy_orders, order.price, order)
    %{market_state | buy_orders: buy_orders}
  end

  defp add_to_queue(market_state, %Order{side: "sell"} = order) do
    sell_orders = PriorityQueue.insert_sell(market_state.sell_orders, order.price, order)
    %{market_state | sell_orders: sell_orders}
  end

  defp remove_from_queue(market_state, %Order{side: "buy"} = order) do
    buy_orders = PriorityQueue.remove(market_state.buy_orders, order)
    %{market_state | buy_orders: buy_orders}
  end

  defp remove_from_queue(market_state, %Order{side: "sell"} = order) do
    sell_orders = PriorityQueue.remove(market_state.sell_orders, order)
    %{market_state | sell_orders: sell_orders}
  end

  defp match_orders(%{buy_orders: buy_orders, sell_orders: sell_orders} = market_state) do
    case {PriorityQueue.peek(buy_orders), PriorityQueue.peek(sell_orders)} do
      {nil, _} -> {market_state, []}
      {_, nil} -> {market_state, []}
      {buy_order, sell_order} ->
        if matchable?(buy_order, sell_order) do
          # Calculate match amount and price
          match_amount = min(
            Decimal.sub(buy_order.amount, buy_order.filled_amount),
            Decimal.sub(sell_order.amount, sell_order.filled_amount)
          )
          match_price = sell_order.price  # Use sell order price for matching

          # Create match record
          match = %{
            buy_order: buy_order,
            sell_order: sell_order,
            amount: match_amount,
            price: match_price
          }

          # Update orders
          {updated_market_state, more_matches} = update_orders_after_match(
            market_state,
            buy_order,
            sell_order,
            match_amount
          )

          {updated_market_state, [match | more_matches]}
        else
          {market_state, []}
        end
    end
  end

  defp matchable?(buy_order, sell_order) do
    Decimal.compare(buy_order.price, sell_order.price) in [:gt, :eq]
  end

  defp update_orders_after_match(market_state, buy_order, sell_order, match_amount) do
    # Update filled amounts
    buy_order = update_filled_amount(buy_order, match_amount)
    sell_order = update_filled_amount(sell_order, match_amount)

    # Remove filled orders and update queues
    market_state = if order_filled?(buy_order) do
      remove_from_queue(market_state, buy_order)
    else
      update_in_queue(market_state, buy_order)
    end

    market_state = if order_filled?(sell_order) do
      remove_from_queue(market_state, sell_order)
    else
      update_in_queue(market_state, sell_order)
    end

    # Try to match more orders
    match_orders(market_state)
  end

  defp update_filled_amount(order, match_amount) do
    new_filled_amount = Decimal.add(order.filled_amount, match_amount)
    %{order | filled_amount: new_filled_amount}
  end

  defp order_filled?(order) do
    Decimal.compare(order.filled_amount, order.amount) == :eq
  end

  defp update_in_queue(market_state, %Order{side: "buy"} = order) do
    buy_orders = PriorityQueue.update(market_state.buy_orders, order)
    %{market_state | buy_orders: buy_orders}
  end

  defp update_in_queue(market_state, %Order{side: "sell"} = order) do
    sell_orders = PriorityQueue.update(market_state.sell_orders, order)
    %{market_state | sell_orders: sell_orders}
  end

  defp execute_matches([]), do: :ok
  defp execute_matches([match | rest]) do
    case Trade.execute_trade(match) do
      {:ok, _} ->
        broadcast_trade(match)
        execute_matches(rest)
      
      {:error, reason} ->
        Logger.error("Failed to execute trade: #{inspect(reason)}")
        # Continue with remaining matches even if one fails
        execute_matches(rest)
    end
  end

  defp broadcast_trade(match) do
    market = "#{match.buy_order.base_currency}_#{match.buy_order.quote_currency}"
    PubSub.broadcast(
      @pubsub,
      "trades:#{market}",
      {:trade_executed, match}
    )
  end

  defp broadcast_order_book(market, market_state) do
    order_book = %{
      buy_orders: serialize_orders(market_state.buy_orders),
      sell_orders: serialize_orders(market_state.sell_orders)
    }

    PubSub.broadcast(
      @pubsub,
      "orderbook:#{market}",
      {:order_book_updated, order_book}
    )
  end

  defp serialize_orders(queue) do
    queue
    |> :gb_trees.to_list()
    |> Enum.map(fn {_key, order} -> 
      %{
        id: order.id,
        price: order.price,
        amount: order.amount,
        filled_amount: order.filled_amount,
        side: order.side
      }
    end)
  end
end
