defmodule FycApp.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:users) do
      # size: 160
      add :email, :citext, null: false
      # bcrypt hash is always 60 chars
      add :hashed_password, :string, null: false, size: 72
      add :confirmed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create constraint(:users, :email_must_have_at_sign, check: "email ~ '@'")

    create table(:users_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      # for 256-bit tokens
      # , size: 32
      add :token, :binary, null: false
      add :context, :string, null: false, size: 32
      # same as email size
      add :sent_to, :string, size: 160

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end
end
