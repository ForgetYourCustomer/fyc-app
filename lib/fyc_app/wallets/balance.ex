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

  @doc """
  Creates a changeset for updating USDT balance with a deposit.
  The deposit amount is expected to be a string representing a u256 number.
  """
  def deposit_usdt_balance_changeset(balance, deposit_amount) when is_binary(deposit_amount) do
    current_amount = balance.amount || 0
    deposit_int = String.to_integer(deposit_amount)
    new_amount = current_amount + deposit_int

    balance
    |> cast(%{amount: new_amount}, [:amount])
    |> validate_required([:amount])
    |> validate_number(:amount, greater_than_or_equal_to: 0)
  end
end
