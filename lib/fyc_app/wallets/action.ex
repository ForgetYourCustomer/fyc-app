defmodule FycApp.Wallets.Action do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @action_types ["deposit", "withdraw", "order_create", "order_complete", "order_cancel"]
  @base_fields [:action_type, :wallet_id]

  schema "actions" do
    field :action_type, :string
    field :in_amount, :integer
    field :in_currency, :string
    field :out_amount, :integer
    field :out_currency, :string
    belongs_to :wallet, FycApp.Wallets.Wallet

    timestamps()
  end

  @doc """
  Creates a changeset for the Action schema based on the action type.
  Different validations are applied based on the action_type:

  deposit:
    - in_amount: positive integer (required)
    - in_currency: non-empty string (required)
    - out_amount: must be null
    - out_currency: must be null

  withdraw:
    - out_amount: positive integer (required)
    - out_currency: non-empty string (required)
    - in_amount: must be null
    - in_currency: must be null

  order_create/complete/cancel:
    - in_amount and out_amount: positive integers (required)
    - in_currency and out_currency: different non-empty strings (required)
  """
  def changeset(action, %{action_type: "deposit"} = attrs) do
    action
    |> cast(attrs, @base_fields ++ [:in_amount, :in_currency])
    |> validate_required(@base_fields ++ [:in_amount, :in_currency])
    |> validate_inclusion(:action_type, @action_types)
    |> validate_number(:in_amount, greater_than: 0)
    |> validate_currency(:in_currency)
    |> ensure_null_fields([:out_amount, :out_currency])
    |> foreign_key_constraint(:wallet_id)
  end

  def changeset(action, %{action_type: "withdraw"} = attrs) do
    action
    |> cast(attrs, @base_fields ++ [:out_amount, :out_currency])
    |> validate_required(@base_fields ++ [:out_amount, :out_currency])
    |> validate_inclusion(:action_type, @action_types)
    |> validate_number(:out_amount, greater_than: 0)
    |> validate_currency(:out_currency)
    |> ensure_null_fields([:in_amount, :in_currency])
    |> foreign_key_constraint(:wallet_id)
  end

  def changeset(action, %{action_type: action_type} = attrs)
      when action_type in ["order_create", "order_complete", "order_cancel"] do
    action
    |> cast(attrs, @base_fields ++ [:in_amount, :in_currency, :out_amount, :out_currency])
    |> validate_required(@base_fields ++ [:in_amount, :in_currency, :out_amount, :out_currency])
    |> validate_inclusion(:action_type, @action_types)
    |> validate_number(:in_amount, greater_than: 0)
    |> validate_number(:out_amount, greater_than: 0)
    |> validate_currency(:in_currency)
    |> validate_currency(:out_currency)
    |> validate_different_currencies()
    |> foreign_key_constraint(:wallet_id)
  end

  def changeset(action, attrs) do
    action
    |> cast(attrs, @base_fields)
    |> add_error(:action_type, "is invalid")
  end

  # Private helper functions

  defp validate_currency(changeset, field) do
    validate_change(changeset, field, fn field, value ->
      if is_binary(value) && String.trim(value) != "" do
        []
      else
        [{field, "must be a non-empty string"}]
      end
    end)
  end

  defp validate_different_currencies(changeset) do
    in_currency = get_field(changeset, :in_currency)
    out_currency = get_field(changeset, :out_currency)

    if in_currency && out_currency && in_currency == out_currency do
      add_error(changeset, :out_currency, "must be different from in_currency")
    else
      changeset
    end
  end

  defp ensure_null_fields(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, acc ->
      case get_field(acc, field) do
        nil -> acc
        _ -> add_error(acc, field, "must be null")
      end
    end)
  end
end
