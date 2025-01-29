defmodule FycApp.TradeFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `FycApp.Trade` context.
  """

  @doc """
  Generate a order.
  """
  def order_fixture(attrs \\ %{}) do
    {:ok, order} =
      attrs
      |> Enum.into(%{
        amount: "120.5",
        base_currency: "some base_currency",
        client_order_id: "some client_order_id",
        filled_amount: "120.5",
        order_type: "some order_type",
        price: "120.5",
        quote_currency: "some quote_currency",
        side: "some side",
        status: "some status"
      })
      |> FycApp.Trade.create_order()

    order
  end

  @doc """
  Generate a locked_balance.
  """
  def locked_balance_fixture(attrs \\ %{}) do
    {:ok, locked_balance} =
      attrs
      |> Enum.into(%{
        amount: "120.5",
        currency: "some currency"
      })
      |> FycApp.Trade.create_locked_balance()

    locked_balance
  end

  @doc """
  Generate a trade_execution.
  """
  def trade_execution_fixture(attrs \\ %{}) do
    {:ok, trade_execution} =
      attrs
      |> Enum.into(%{
        amount: "120.5",
        price: "120.5",
        total: "120.5"
      })
      |> FycApp.Trade.create_trade_execution()

    trade_execution
  end
end
