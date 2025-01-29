defmodule FycApp.Repo.Migrations.CreateBalances do
  use Ecto.Migration

  def change do
    create table(:balances, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :amount, :bigint, null: false
      add :currency, :string, null: false
      add :wallet_id, references(:wallets, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:balances, [:wallet_id])
  end
end
