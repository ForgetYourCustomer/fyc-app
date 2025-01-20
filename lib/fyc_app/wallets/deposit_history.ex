defmodule FycApp.Wallets.DepositHistory do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "deposit_history" do
    field :deposit_address, :string
    field :amount, :decimal
    field :tx_id, :string

    belongs_to :balance, FycApp.Wallets.Balance

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(deposit_history, attrs) do
    deposit_history
    |> cast(attrs, [:balance_id, :deposit_address, :amount, :tx_id])
    |> validate_required([:balance_id, :deposit_address, :amount, :tx_id])
    |> unique_constraint(:tx_id, name: :deposit_history_tx_id_unique_index)
  end
end
