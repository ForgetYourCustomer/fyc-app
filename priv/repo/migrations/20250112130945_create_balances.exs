defmodule FycApp.Repo.Migrations.CreateBalances do
  use Ecto.Migration

  def change do
    create table(:balances) do
      add :amount, :bigint, null: false
      add :currency, :string, null: false
      add :wallet_id, references(:wallets, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:balances, [:wallet_id])
  end
end
