defmodule FycApp.Repo.Migrations.UpdateActionAmountFields do
  use Ecto.Migration

  def change do
    alter table(:actions) do
      modify :in_amount, :integer, null: true
      modify :in_currency, :string, null: true
      modify :out_amount, :integer, null: true
      modify :out_currency, :string, null: true
    end
  end
end
