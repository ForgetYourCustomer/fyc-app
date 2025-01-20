defmodule FycAppWeb.WalletLive.FormComponent do
  use FycAppWeb, :live_component

  alias FycApp.Wallets

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage wallet records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="wallet-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >

        <:actions>
          <.button phx-disable-with="Saving...">Save Wallet</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{wallet: wallet} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Wallets.change_wallet(wallet))
     end)}
  end

  @impl true
  def handle_event("validate", %{"wallet" => wallet_params}, socket) do
    changeset = Wallets.change_wallet(socket.assigns.wallet, wallet_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"wallet" => wallet_params}, socket) do
    save_wallet(socket, socket.assigns.action, wallet_params)
  end

  defp save_wallet(socket, :edit, wallet_params) do
    case Wallets.update_wallet(socket.assigns.wallet, wallet_params) do
      {:ok, wallet} ->
        notify_parent({:saved, wallet})

        {:noreply,
         socket
         |> put_flash(:info, "Wallet updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_wallet(socket, :new, wallet_params) do
    case Wallets.create_wallet(wallet_params) do
      {:ok, wallet} ->
        notify_parent({:saved, wallet})

        {:noreply,
         socket
         |> put_flash(:info, "Wallet created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
