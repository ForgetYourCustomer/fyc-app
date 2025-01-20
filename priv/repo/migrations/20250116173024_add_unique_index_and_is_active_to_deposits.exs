defmodule FycApp.Repo.Migrations.AddUniqueIndexAndIsActiveToDeposits do
  use Ecto.Migration

  def change do
    alter table(:deposits) do
      add :is_active, :boolean, default: true, null: false
    end

    drop_if_exists index(:deposits, [:address])
    create unique_index(:deposits, [:address])
  end
end
