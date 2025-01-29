defmodule FycApp.Repo.Migrations.CreateOrders do
  use Ecto.Migration

  def change do
    create table(:orders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :order_type, :string, null: false
      add :side, :string, null: false
      add :base_currency, :string, null: false
      add :quote_currency, :string, null: false
      add :price, :decimal, null: false, precision: 20, scale: 8
      add :amount, :decimal, null: false, precision: 20, scale: 8
      add :filled_amount, :decimal, null: false, precision: 20, scale: 8, default: 0
      add :status, :string, null: false, default: "pending"
      add :client_order_id, :string, null: false
      add :user_id, references(:users, on_delete: :nothing, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:orders, [:user_id])
    create unique_index(:orders, [:client_order_id])
    create index(:orders, [:status])
    create index(:orders, [:base_currency, :quote_currency])
    # Index for order matching
    create index(:orders, [:base_currency, :quote_currency, :side, :price])
  end
end
