defmodule FycApp.Trade.LockedBalance do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "locked_balances" do
    field :amount, :integer
    field :currency, :string
    belongs_to :user, FycApp.Accounts.User
    belongs_to :order, FycApp.Trade.Order

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a locked balance.

  ## Validations
    - amount must be positive
    - currency must be present
    - user_id must be present
    - order_id must be present
  """
  def changeset(locked_balance, attrs) do
    locked_balance
    |> cast(attrs, [:amount, :currency, :user_id, :order_id])
    |> validate_required([:amount, :currency, :user_id, :order_id])
    |> validate_number(:amount, greater_than: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:order_id)
    |> unique_constraint([:user_id, :currency, :order_id])
  end
end
