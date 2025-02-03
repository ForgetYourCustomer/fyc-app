defmodule FycApp.Repo.Migrations.AlterTradeExecutionToBigint do
  use Ecto.Migration

  def change do
    alter table(:trades) do
      modify :price, :bigint, from: :decimal
      modify :amount, :bigint, from: :decimal
      modify :total, :bigint, from: :decimal
    end
  end
end
