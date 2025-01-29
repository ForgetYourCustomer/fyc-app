defmodule FycAppWeb.WalletLive.Index do
  use FycAppWeb, :live_view

  alias FycApp.Wallets
  alias FycApp.Wallets.Wallet

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns.current_user do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "You must be logged in to view your wallet")
         |> redirect(to: ~p"/")}

      current_user ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(FycApp.PubSub, "wallet:#{current_user.id}")
        end
        
        {:ok, assign(socket, :wallet, Wallets.get_user_wallet(current_user.id))}
    end
  end

  @impl true
  def handle_info({:balance_updated, currency, amount}, socket) do
    updated_wallet = update_in(
      socket.assigns.wallet,
      [Access.key(:balances)],
      fn balances ->
        Enum.map(balances, fn
          %{currency: ^currency} = balance -> %{balance | amount: amount}
          balance -> balance
        end)
      end
    )

    {:noreply, assign(socket, :wallet, updated_wallet)}
  end

  @impl true
  def handle_info({:wallet_updated, wallet}, socket) do
    {:noreply, assign(socket, :wallet, wallet)}
  end

  # Ignore updates for other wallets
  def update(_assigns, socket), do: {:ok, socket}

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Wallet")
    |> assign(:wallet, Wallets.get_wallet!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Wallet")
    |> assign(:wallet, %Wallet{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Wallets")
    |> assign(:wallet, nil)
  end

  @impl true
  def handle_info({FycAppWeb.WalletLive.FormComponent, {:saved, wallet}}, socket) do
    {:noreply, assign(socket, :wallet, wallet)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    wallet = Wallets.get_wallet!(id)
    {:ok, _} = Wallets.delete_wallet(wallet)

    {:noreply, assign(socket, :wallet, nil)}
  end
end
