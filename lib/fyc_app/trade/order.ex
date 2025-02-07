defmodule FycApp.Trade.Order do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @derive {Jason.Encoder, only: [:id, :price, :amount, :filled_amount, :side, :status, :inserted_at]}

  @order_types ["limit", "market"]
  @order_sides ["buy", "sell"]
  @order_statuses ["pending", "partial", "filled", "cancelled", "partially_cancelled"]
  @supported_pairs [
    {"BTC", "USDT"}
  ]

  schema "orders" do
    field :order_type, :string
    field :side, :string
    field :base_currency, :string
    field :quote_currency, :string
    field :price, :integer
    field :amount, :integer
    field :filled_amount, :integer, default: 0
    field :status, :string, default: "pending"
    field :client_order_id, :string
    belongs_to :user, FycApp.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a new order.

  ## Parameters
    - order: The order struct to create a changeset for
    - attrs: The attributes to create the order with

  ## Validations
    - order_type must be one of: #{inspect(@order_types)}
    - side must be one of: #{inspect(@order_sides)}
    - status must be one of: #{inspect(@order_statuses)}
    - price must be positive
    - amount must be positive
    - filled_amount must be non-negative and less than or equal to amount
    - trading pair must be supported
    - client_order_id must be unique
  """
  def changeset(order, attrs) do
    order
    |> cast(attrs, [
      :order_type,
      :side,
      :base_currency,
      :quote_currency,
      :price,
      :amount,
      :filled_amount,
      :status,
      :client_order_id,
      :user_id
    ])
    |> validate_required([
      :order_type,
      :side,
      :base_currency,
      :quote_currency,
      :price,
      :amount,
      :status,
      :client_order_id,
      :user_id
    ])
    |> validate_inclusion(:order_type, @order_types)
    |> validate_inclusion(:side, @order_sides)
    |> validate_inclusion(:status, @order_statuses)
    |> validate_number(:price, greater_than: 0)
    |> validate_number(:amount, greater_than: 0)
    |> validate_number(:filled_amount, greater_than_or_equal_to: 0)
    |> validate_filled_amount()
    |> validate_trading_pair()
    |> unique_constraint(:client_order_id)
  end

  def create_limit_order_changeset(order, attrs) do
    attrs = Map.put(attrs, :order_type, "limit") |> Map.put(:status, "pending")

    order
    |> cast(attrs, [
      :order_type,
      :side,
      :base_currency,
      :quote_currency,
      :price,
      :amount,
      :status,
      :client_order_id,
      :user_id
    ])
    |> validate_required([
      :order_type,
      :side,
      :base_currency,
      :quote_currency,
      :price,
      :amount,
      :status,
      :client_order_id,
      :user_id
    ])
    |> validate_inclusion(:side, @order_sides)
    |> validate_number(:price, greater_than: 0)
    |> validate_number(:amount, greater_than: 0)
    |> validate_number(:filled_amount, greater_than_or_equal_to: 0)
    |> validate_filled_amount()
    |> validate_trading_pair()
    |> unique_constraint(:client_order_id)
  end

  defp validate_filled_amount(changeset) do
    case {get_field(changeset, :amount), get_field(changeset, :filled_amount)} do
      {nil, _} ->
        changeset

      {_, nil} ->
        changeset

      {amount, filled_amount} ->
        if filled_amount > amount do
          add_error(changeset, :filled_amount, "cannot be greater than amount")
        else
          changeset
        end
    end
  end

  defp validate_trading_pair(changeset) do
    case {get_field(changeset, :base_currency), get_field(changeset, :quote_currency)} do
      {nil, _} ->
        changeset

      {_, nil} ->
        changeset

      {base, quote} ->
        if {base, quote} in @supported_pairs do
          changeset
        else
          add_error(changeset, :base_currency, "trading pair not supported")
        end
    end
  end
end
