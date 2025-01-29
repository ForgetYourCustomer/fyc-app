defmodule FycApp.Repo.Migrations.CreateActions do
  use Ecto.Migration

  def change do
    create table(:actions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :action_type, :string, null: false
      add :in_amount, :integer, null: false
      add :in_currency, :string, null: false
      add :out_amount, :integer, null: false
      add :out_currency, :string, null: false
      add :wallet_id, references(:wallets, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:actions, [:wallet_id])
    create constraint(:actions, :action_type_must_be_valid,
      check: "action_type IN ('deposit', 'withdraw', 'order_create', 'order_complete', 'order_cancel')")
  end
end
