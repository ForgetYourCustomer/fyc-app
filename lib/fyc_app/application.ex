defmodule FycApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      FycAppWeb.Telemetry,
      # Start the Ecto repository
      FycApp.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: FycApp.PubSub},
      # Start Finch
      {Finch, name: FycApp.Finch},
      # Start the Endpoint (http/https)
      FycAppWeb.Endpoint,
      # Start the matching engine for trade execution
      FycApp.Trade.MatchingEngine
    ]

    :ok = Application.ensure_started(:chumak)
    children = children ++ [FycApp.Bitserv.Listener]
    children = children ++ [FycApp.Ethserv.Listener]

    opts = [strategy: :one_for_one, name: FycApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FycAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
