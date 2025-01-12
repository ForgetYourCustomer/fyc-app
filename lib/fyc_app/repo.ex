defmodule FycApp.Repo do
  use Ecto.Repo,
    otp_app: :fyc_app,
    adapter: Ecto.Adapters.Postgres
end
