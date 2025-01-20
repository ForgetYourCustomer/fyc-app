defmodule FycApp.Wallets.Balance do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "balances" do
    field :amount, :integer
    field :currency, :string
    belongs_to :wallet, FycApp.Wallets.Wallet
    has_many :deposits, FycApp.Wallets.Deposit
    has_many :deposit_history, FycApp.Wallets.DepositHistory

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(balance, attrs) do
    balance
    |> cast(attrs, [:amount, :currency, :wallet_id])
    |> validate_required([:amount, :currency, :wallet_id])
    |> validate_number(:amount, greater_than_or_equal_to: 0)
    |> validate_inclusion(:currency, ["BTC", "USDT"])
    |> cast_assoc(:deposits)
  end
end
