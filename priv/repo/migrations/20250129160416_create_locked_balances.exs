defmodule FycApp.Repo.Migrations.CreateLockedBalances do
  use Ecto.Migration

  def change do
    create table(:locked_balances, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :amount, :decimal, null: false, precision: 20, scale: 8
      add :currency, :string, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :order_id, references(:orders, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:locked_balances, [:user_id])
    create index(:locked_balances, [:order_id])
    create unique_index(:locked_balances, [:user_id, :currency, :order_id])
  end
end
