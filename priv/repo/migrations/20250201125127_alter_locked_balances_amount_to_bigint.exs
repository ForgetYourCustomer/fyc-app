defmodule FycApp.Repo.Migrations.AlterLockedBalancesAmountToBigint do
  use Ecto.Migration

  def change do
    alter table(:locked_balances) do
      modify :amount, :bigint, from: :decimal
    end
  end
end
