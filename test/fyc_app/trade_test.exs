defmodule FycApp.TradeTest do
  use FycApp.DataCase

  alias FycApp.Trade

  describe "orders" do
    alias FycApp.Trade.Order

    import FycApp.TradeFixtures

    @invalid_attrs %{status: nil, order_type: nil, side: nil, base_currency: nil, quote_currency: nil, price: nil, amount: nil, filled_amount: nil, client_order_id: nil}

    test "list_orders/0 returns all orders" do
      order = order_fixture()
      assert Trade.list_orders() == [order]
    end

    test "get_order!/1 returns the order with given id" do
      order = order_fixture()
      assert Trade.get_order!(order.id) == order
    end

    test "create_order/1 with valid data creates a order" do
      valid_attrs = %{status: "some status", order_type: "some order_type", side: "some side", base_currency: "some base_currency", quote_currency: "some quote_currency", price: "120.5", amount: "120.5", filled_amount: "120.5", client_order_id: "some client_order_id"}

      assert {:ok, %Order{} = order} = Trade.create_order(valid_attrs)
      assert order.status == "some status"
      assert order.order_type == "some order_type"
      assert order.side == "some side"
      assert order.base_currency == "some base_currency"
      assert order.quote_currency == "some quote_currency"
      assert order.price == Decimal.new("120.5")
      assert order.amount == Decimal.new("120.5")
      assert order.filled_amount == Decimal.new("120.5")
      assert order.client_order_id == "some client_order_id"
    end

    test "create_order/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Trade.create_order(@invalid_attrs)
    end

    test "update_order/2 with valid data updates the order" do
      order = order_fixture()
      update_attrs = %{status: "some updated status", order_type: "some updated order_type", side: "some updated side", base_currency: "some updated base_currency", quote_currency: "some updated quote_currency", price: "456.7", amount: "456.7", filled_amount: "456.7", client_order_id: "some updated client_order_id"}

      assert {:ok, %Order{} = order} = Trade.update_order(order, update_attrs)
      assert order.status == "some updated status"
      assert order.order_type == "some updated order_type"
      assert order.side == "some updated side"
      assert order.base_currency == "some updated base_currency"
      assert order.quote_currency == "some updated quote_currency"
      assert order.price == Decimal.new("456.7")
      assert order.amount == Decimal.new("456.7")
      assert order.filled_amount == Decimal.new("456.7")
      assert order.client_order_id == "some updated client_order_id"
    end

    test "update_order/2 with invalid data returns error changeset" do
      order = order_fixture()
      assert {:error, %Ecto.Changeset{}} = Trade.update_order(order, @invalid_attrs)
      assert order == Trade.get_order!(order.id)
    end

    test "delete_order/1 deletes the order" do
      order = order_fixture()
      assert {:ok, %Order{}} = Trade.delete_order(order)
      assert_raise Ecto.NoResultsError, fn -> Trade.get_order!(order.id) end
    end

    test "change_order/1 returns a order changeset" do
      order = order_fixture()
      assert %Ecto.Changeset{} = Trade.change_order(order)
    end
  end

  describe "locked_balances" do
    alias FycApp.Trade.LockedBalance

    import FycApp.TradeFixtures

    @invalid_attrs %{currency: nil, amount: nil}

    test "list_locked_balances/0 returns all locked_balances" do
      locked_balance = locked_balance_fixture()
      assert Trade.list_locked_balances() == [locked_balance]
    end

    test "get_locked_balance!/1 returns the locked_balance with given id" do
      locked_balance = locked_balance_fixture()
      assert Trade.get_locked_balance!(locked_balance.id) == locked_balance
    end

    test "create_locked_balance/1 with valid data creates a locked_balance" do
      valid_attrs = %{currency: "some currency", amount: "120.5"}

      assert {:ok, %LockedBalance{} = locked_balance} = Trade.create_locked_balance(valid_attrs)
      assert locked_balance.currency == "some currency"
      assert locked_balance.amount == Decimal.new("120.5")
    end

    test "create_locked_balance/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Trade.create_locked_balance(@invalid_attrs)
    end

    test "update_locked_balance/2 with valid data updates the locked_balance" do
      locked_balance = locked_balance_fixture()
      update_attrs = %{currency: "some updated currency", amount: "456.7"}

      assert {:ok, %LockedBalance{} = locked_balance} = Trade.update_locked_balance(locked_balance, update_attrs)
      assert locked_balance.currency == "some updated currency"
      assert locked_balance.amount == Decimal.new("456.7")
    end

    test "update_locked_balance/2 with invalid data returns error changeset" do
      locked_balance = locked_balance_fixture()
      assert {:error, %Ecto.Changeset{}} = Trade.update_locked_balance(locked_balance, @invalid_attrs)
      assert locked_balance == Trade.get_locked_balance!(locked_balance.id)
    end

    test "delete_locked_balance/1 deletes the locked_balance" do
      locked_balance = locked_balance_fixture()
      assert {:ok, %LockedBalance{}} = Trade.delete_locked_balance(locked_balance)
      assert_raise Ecto.NoResultsError, fn -> Trade.get_locked_balance!(locked_balance.id) end
    end

    test "change_locked_balance/1 returns a locked_balance changeset" do
      locked_balance = locked_balance_fixture()
      assert %Ecto.Changeset{} = Trade.change_locked_balance(locked_balance)
    end
  end

  describe "trades" do
    alias FycApp.Trade.TradeExecution

    import FycApp.TradeFixtures

    @invalid_attrs %{total: nil, price: nil, amount: nil}

    test "list_trades/0 returns all trades" do
      trade_execution = trade_execution_fixture()
      assert Trade.list_trades() == [trade_execution]
    end

    test "get_trade_execution!/1 returns the trade_execution with given id" do
      trade_execution = trade_execution_fixture()
      assert Trade.get_trade_execution!(trade_execution.id) == trade_execution
    end

    test "create_trade_execution/1 with valid data creates a trade_execution" do
      valid_attrs = %{total: "120.5", price: "120.5", amount: "120.5"}

      assert {:ok, %TradeExecution{} = trade_execution} = Trade.create_trade_execution(valid_attrs)
      assert trade_execution.total == Decimal.new("120.5")
      assert trade_execution.price == Decimal.new("120.5")
      assert trade_execution.amount == Decimal.new("120.5")
    end

    test "create_trade_execution/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Trade.create_trade_execution(@invalid_attrs)
    end

    test "update_trade_execution/2 with valid data updates the trade_execution" do
      trade_execution = trade_execution_fixture()
      update_attrs = %{total: "456.7", price: "456.7", amount: "456.7"}

      assert {:ok, %TradeExecution{} = trade_execution} = Trade.update_trade_execution(trade_execution, update_attrs)
      assert trade_execution.total == Decimal.new("456.7")
      assert trade_execution.price == Decimal.new("456.7")
      assert trade_execution.amount == Decimal.new("456.7")
    end

    test "update_trade_execution/2 with invalid data returns error changeset" do
      trade_execution = trade_execution_fixture()
      assert {:error, %Ecto.Changeset{}} = Trade.update_trade_execution(trade_execution, @invalid_attrs)
      assert trade_execution == Trade.get_trade_execution!(trade_execution.id)
    end

    test "delete_trade_execution/1 deletes the trade_execution" do
      trade_execution = trade_execution_fixture()
      assert {:ok, %TradeExecution{}} = Trade.delete_trade_execution(trade_execution)
      assert_raise Ecto.NoResultsError, fn -> Trade.get_trade_execution!(trade_execution.id) end
    end

    test "change_trade_execution/1 returns a trade_execution changeset" do
      trade_execution = trade_execution_fixture()
      assert %Ecto.Changeset{} = Trade.change_trade_execution(trade_execution)
    end
  end
end
