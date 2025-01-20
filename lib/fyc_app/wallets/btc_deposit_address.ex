defmodule FycApp.Wallets.BtcDepositAddress do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:deposit_id, :integer, autogenerate: false}
  schema "btc_deposit_addresses" do
    field :address, :string
    belongs_to :wallet, FycApp.Wallets.Wallet

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(btc_deposit_address, attrs) do
    btc_deposit_address
    |> cast(attrs, [:deposit_id, :address, :wallet_id])
    |> validate_required([:deposit_id, :address, :wallet_id])
    |> unique_constraint(:address)
    |> foreign_key_constraint(:wallet_id)
  end
end
