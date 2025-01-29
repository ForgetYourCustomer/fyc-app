defmodule FycApp.Repo.Migrations.CreateBtcDepositAddresses do
  use Ecto.Migration

  def change do
    create table(:btc_deposit_addresses, primary_key: false) do
      add :deposit_id, :integer, primary_key: true
      add :address, :string, null: false
      add :wallet_id, references(:wallets, type: :binary_id, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:btc_deposit_addresses, [:address])
    create index(:btc_deposit_addresses, [:wallet_id])
  end
end
