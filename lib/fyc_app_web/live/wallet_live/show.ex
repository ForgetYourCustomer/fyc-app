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

        if connected?(socket) do
          Phoenix.PubSub.subscribe(FycApp.PubSub, "wallet:#{wallet.id}")
        end

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
    IO.inspect(balance, label: "Balance to create deposit for")

    case Deposits.create_deposit(balance) do
      {:ok, deposit} ->
        # Update the wallet's balances with the new deposit
        balance_id = balance.id

        updated_wallet =
          update_in(
            socket.assigns.wallet,
            [Access.key(:balances)],
            fn balances ->
              Enum.map(balances, fn
                %{id: ^balance_id} = b -> %{b | deposits: [deposit | b.deposits || []]}
                other_balance -> other_balance
              end)
            end
          )

        {:noreply,
         socket
         |> assign(:wallet, updated_wallet)
         |> put_flash(:info, "Deposit address created successfully.")
         |> push_event("copy", %{text: deposit.address})}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply, put_flash(socket, :error, "Error creating deposit address.")}
    end
  end

  @impl true
  def handle_info({:balance_updated, currency, new_amount}, socket) do
    updated_balances =
      Enum.map(socket.assigns.wallet.balances, fn balance ->
        if balance.currency == currency do
          %{balance | amount: new_amount}
        else
          balance
        end
      end)

    wallet = %{socket.assigns.wallet | balances: updated_balances}
    {:noreply, assign(socket, :wallet, wallet)}
  end

  # Convert BTC sats to BTC (1 BTC = 100,000,000 sats)
  # Convert USDT u256 (6 decimals) to USDT with 2 decimal places
  defp format_balance_amount(amount, currency) do
    case currency do
      "BTC" ->
        btc = amount / 100_000_000
        :erlang.float_to_binary(btc, decimals: 8)

      "USDT" ->
        # Convert from 6 decimals to whole USDT
        usdt = amount / 1_000_000
        :erlang.float_to_binary(usdt, decimals: 2)
    end
  end
end
