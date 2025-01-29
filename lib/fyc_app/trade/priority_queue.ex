defmodule FycApp.Trade.PriorityQueue do
  @moduledoc """
  A priority queue implementation using :gb_trees for efficient order book management.
  Orders are sorted by price and time priority (FIFO for same price).
  """

  @doc """
  Creates a new empty priority queue.
  """
  def new(), do: :gb_trees.empty()

  @doc """
  Inserts a buy order into the queue.
  Buy orders are sorted by highest price first (descending).
  """
  def insert_buy(queue, price, order) do
    # Negate price for reverse ordering
    key = {Decimal.negate(price), order.inserted_at, order.id}
    :gb_trees.insert(key, order, queue)
  end

  @doc """
  Inserts a sell order into the queue.
  Sell orders are sorted by lowest price first (ascending).
  """
  def insert_sell(queue, price, order) do
    key = {price, order.inserted_at, order.id}
    :gb_trees.insert(key, order, queue)
  end

  @doc """
  Removes an order from the queue.
  """
  def remove(queue, order) do
    key = find_key(queue, order)
    case key do
      nil -> queue
      key -> :gb_trees.delete(key, queue)
    end
  end

  @doc """
  Updates an existing order in the queue.
  """
  def update(queue, order) do
    case find_key(queue, order) do
      nil -> 
        queue
      key ->
        queue
        |> :gb_trees.delete(key)
        |> :gb_trees.insert(key, order)
    end
  end

  @doc """
  Returns the highest priority order without removing it.
  """
  def peek(queue) do
    case :gb_trees.size(queue) do
      0 -> nil
      _ -> 
        {_key, order} = :gb_trees.smallest(queue)
        order
    end
  end

  @doc """
  Returns and removes the highest priority order.
  """
  def pop(queue) do
    case :gb_trees.size(queue) do
      0 -> 
        {nil, queue}
      _ ->
        {key, order, new_queue} = :gb_trees.take_smallest(queue)
        {order, new_queue}
    end
  end

  # Private Functions

  defp find_key(queue, target_order) do
    :gb_trees.iterator(queue)
    |> find_key_iter(target_order)
  end

  defp find_key_iter(iter, target_order) do
    case :gb_trees.next(iter) do
      none when none in [:none, none] ->
        nil
      {key, order, _next_iter} when order.id == target_order.id ->
        key
      {_key, _order, next_iter} ->
        find_key_iter(next_iter, target_order)
    end
  end
end
