defmodule FycApp.Repo.Migrations.AlterActionAmountsToBigint do
  use Ecto.Migration

  def change do
    alter table(:actions) do
      modify :in_amount, :bigint, null: true
      modify :out_amount, :bigint, null: true
    end
  end
end
