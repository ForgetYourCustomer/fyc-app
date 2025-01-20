defmodule FycApp.Repo.Migrations.CreateDepositsAndDropBtcDepositAddresses do
  use Ecto.Migration

  def change do
    drop table(:btc_deposit_addresses)

    create table(:deposits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :address, :string, null: false
      add :metadata, :map, default: %{}
      add :balance_id, references(:balances), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:deposits, [:balance_id])
    create index(:deposits, [:address])
  end
end
