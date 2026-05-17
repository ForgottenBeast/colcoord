defmodule Colcoord.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    base_children = [
      ColcoordWeb.Telemetry,
      Colcoord.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:colcoord, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:colcoord, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Colcoord.PubSub}
    ]

    game_finder =
      if Application.get_env(:colcoord, :start_game_finder, true),
        do: [Colcoord.GameFinder],
        else: []

    children = base_children ++ game_finder ++ [ColcoordWeb.Endpoint]

    opts = [strategy: :one_for_one, name: Colcoord.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ColcoordWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
