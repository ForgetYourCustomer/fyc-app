defmodule FycAppWeb.WalletLive.Show do
  use FycAppWeb, :live_view

  alias FycApp.Wallets
  alias FycApp.Currencies
  alias FycApp.Deposits

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns.current_user do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "You must be logged in to view your wallet")
         |> redirect(to: ~p"/")}

      current_user ->
        # Get wallet and ensure all balances exist
        wallet =
          current_user.id
          |> Wallets.get_user_wallet()
          |> Wallets.ensure_balances_created()
          |> IO.inspect(label: "Wallet with ensured balances", pretty: true)

        {:ok,
         socket
         |> assign(:page_title, "My Wallet")
         |> assign(:wallet, wallet)
         |> assign(:selected_currency, nil)}
    end
  end

  @impl true
  def handle_params(_params, _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle-deposit", %{"currency" => currency}, socket) do
    selected = if socket.assigns.selected_currency == currency, do: nil, else: currency
    {:noreply, assign(socket, :selected_currency, selected)}
  end

  @impl true
  def handle_event("create-deposit", %{"currency" => currency}, socket) do
    balance = Enum.find(socket.assigns.wallet.balances, &(&1.currency == currency))
    IO.inspect(currency, label: "Currency to create deposit for")
    IO.inspect(balance, label: "Balance to create deposit for", pretty: true)

    case Deposits.create_deposit_address(balance) do
      {:ok, _deposit} ->
        # Refresh wallet to get updated deposits
        wallet = Wallets.get_user_wallet(socket.assigns.current_user.id)
        {:noreply, assign(socket, :wallet, wallet)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create deposit address: #{reason}")}
    end
  end
end
