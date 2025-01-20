defmodule FycApp.Repo.Migrations.CreateDepositHistory do
  use Ecto.Migration

  def change do
    create table(:deposit_history, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :balance_id, references(:balances, type: :uuid), null: false
      add :deposit_address, :string, null: false
      add :amount, :decimal, null: false
      add :tx_id, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:deposit_history, [:balance_id])
    create unique_index(:deposit_history, [:tx_id], name: :deposit_history_tx_id_unique_index)
  end
end
