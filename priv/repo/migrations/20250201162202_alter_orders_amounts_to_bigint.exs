defmodule FycApp.Repo.Migrations.AlterOrdersAmountsToBigint do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      modify :price, :bigint, from: :decimal
      modify :amount, :bigint, from: :decimal
      modify :filled_amount, :bigint, from: :decimal
    end
  end
end
