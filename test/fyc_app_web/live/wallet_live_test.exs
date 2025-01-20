defmodule FycAppWeb.WalletLiveTest do
  use FycAppWeb.ConnCase

  import Phoenix.LiveViewTest
  import FycApp.WalletsFixtures

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  defp create_wallet(_) do
    wallet = wallet_fixture()
    %{wallet: wallet}
  end

  describe "Index" do
    setup [:create_wallet]

    test "lists all wallets", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/wallets")

      assert html =~ "Listing Wallets"
    end

    test "saves new wallet", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/wallets")

      assert index_live |> element("a", "New Wallet") |> render_click() =~
               "New Wallet"

      assert_patch(index_live, ~p"/wallets/new")

      assert index_live
             |> form("#wallet-form", wallet: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#wallet-form", wallet: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/wallets")

      html = render(index_live)
      assert html =~ "Wallet created successfully"
    end

    test "updates wallet in listing", %{conn: conn, wallet: wallet} do
      {:ok, index_live, _html} = live(conn, ~p"/wallets")

      assert index_live |> element("#wallets-#{wallet.id} a", "Edit") |> render_click() =~
               "Edit Wallet"

      assert_patch(index_live, ~p"/wallets/#{wallet}/edit")

      assert index_live
             |> form("#wallet-form", wallet: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#wallet-form", wallet: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/wallets")

      html = render(index_live)
      assert html =~ "Wallet updated successfully"
    end

    test "deletes wallet in listing", %{conn: conn, wallet: wallet} do
      {:ok, index_live, _html} = live(conn, ~p"/wallets")

      assert index_live |> element("#wallets-#{wallet.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#wallets-#{wallet.id}")
    end
  end

  describe "Show" do
    setup [:create_wallet]

    test "displays wallet", %{conn: conn, wallet: wallet} do
      {:ok, _show_live, html} = live(conn, ~p"/wallets/#{wallet}")

      assert html =~ "Show Wallet"
    end

    test "updates wallet within modal", %{conn: conn, wallet: wallet} do
      {:ok, show_live, _html} = live(conn, ~p"/wallets/#{wallet}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Wallet"

      assert_patch(show_live, ~p"/wallets/#{wallet}/show/edit")

      assert show_live
             |> form("#wallet-form", wallet: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#wallet-form", wallet: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/wallets/#{wallet}")

      html = render(show_live)
      assert html =~ "Wallet updated successfully"
    end
  end
end
