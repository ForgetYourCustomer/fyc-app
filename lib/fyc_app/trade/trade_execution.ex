defmodule FycApp.Trade.TradeExecution do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "trades" do
    field :price, :integer
    field :amount, :integer
    field :total, :integer
    belongs_to :buy_order, FycApp.Trade.Order
    belongs_to :sell_order, FycApp.Trade.Order

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a trade execution.
  
  ## Validations
    - price must be positive
    - amount must be positive
    - total must equal price * amount
    - buy_order_id and sell_order_id must be present
  """
  def changeset(trade_execution, attrs) do
    trade_execution
    |> cast(attrs, [:price, :amount, :total, :buy_order_id, :sell_order_id])
    |> validate_required([:price, :amount, :total, :buy_order_id, :sell_order_id])
    |> validate_number(:price, greater_than: 0)
    |> validate_number(:amount, greater_than: 0)
    |> validate_total()
    |> foreign_key_constraint(:buy_order_id)
    |> foreign_key_constraint(:sell_order_id)
  end

  defp validate_total(changeset) do
    case {get_field(changeset, :price), get_field(changeset, :amount), get_field(changeset, :total)} do
      {price, amount, total} when is_nil(price) or is_nil(amount) or is_nil(total) ->
        changeset
      {price, amount, total} ->
        expected_total = price * amount
        if total == expected_total do
          changeset
        else
          add_error(changeset, :total, "must equal price * amount")
        end
    end
  end
end
