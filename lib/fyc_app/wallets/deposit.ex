defmodule FycApp.Wallets.Deposit do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "deposits" do
    field :address, :string
    field :metadata, :map, default: %{}
    field :is_active, :boolean, default: true
    belongs_to :balance, FycApp.Wallets.Balance

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(deposit, attrs) do
    deposit
    |> cast(attrs, [:address, :metadata, :balance_id])
    |> validate_required([:address, :balance_id])
    |> unique_constraint(:address)
    |> foreign_key_constraint(:balance_id)
  end

  @doc """
  Changeset for updating an existing deposit.
  Only allows updating metadata and is_active fields.
  """
  def update_changeset(deposit, attrs) do
    deposit
    |> cast(attrs, [:metadata, :is_active])
    |> validate_required([:is_active])
  end

  @doc """
  Changeset for deactivating a deposit.
  Only sets is_active to false.
  """
  def deactivate_changeset(deposit) do
    change(deposit, is_active: false)
  end
end
