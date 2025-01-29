defmodule FycApp.Repo.Migrations.CreateTrades do
  use Ecto.Migration

  def change do
    create table(:trades, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :price, :decimal, null: false, precision: 20, scale: 8
      add :amount, :decimal, null: false, precision: 20, scale: 8
      add :total, :decimal, null: false, precision: 20, scale: 8
      add :buy_order_id, references(:orders, on_delete: :restrict, type: :binary_id), null: false
      add :sell_order_id, references(:orders, on_delete: :restrict, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:trades, [:buy_order_id])
    create index(:trades, [:sell_order_id])
    # Index for querying trades by both orders
    create index(:trades, [:buy_order_id, :sell_order_id])
  end
end
