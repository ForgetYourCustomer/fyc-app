defmodule FycApp.Repo.Migrations.ConvertBalancesToUuid do
  use Ecto.Migration

  def change do
    # Drop existing foreign key constraints
    execute "ALTER TABLE deposits DROP CONSTRAINT deposits_balance_id_fkey"

    # Modify the balances table to use UUID
    alter table(:balances) do
      remove :id
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
    end

    # Update the deposits table to use UUID for balance_id
    alter table(:deposits) do
      remove :balance_id
      add :balance_id, references(:balances, type: :uuid, on_delete: :delete_all)
    end
  end

  def down do
    # Drop foreign key constraints
    execute "ALTER TABLE deposits DROP CONSTRAINT deposits_balance_id_fkey"

    # Revert balances table back to using serial
    alter table(:balances) do
      remove :id
      add :id, :bigserial, primary_key: true
    end

    # Revert deposits table back to using bigint for balance_id
    alter table(:deposits) do
      remove :balance_id
      add :balance_id, references(:balances, on_delete: :delete_all)
    end
  end
end
