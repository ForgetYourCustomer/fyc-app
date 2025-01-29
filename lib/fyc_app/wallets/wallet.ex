defmodule FycApp.Wallets.Wallet do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "wallets" do
    belongs_to :user, FycApp.Accounts.User, type: :binary_id
    has_many :balances, FycApp.Wallets.Balance

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(wallet, attrs) do
    wallet
    |> cast(attrs, [:user_id])
    |> validate_required([:user_id])
    |> cast_assoc(:balances)
  end
end
