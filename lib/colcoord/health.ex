defmodule Colcoord.Health do
  @moduledoc false
  alias Colcoord.GameFinder

  @doc "Liveness: BEAM is up and GameFinder is alive. No DB, no network."
  def liveness do
    if GameFinder.alive?() do
      {200, %{status: "ok", checks: %{game_finder: "up"}}}
    else
      {503, %{status: "error", checks: %{game_finder: "down"}}}
    end
  end

  @doc """
  Readiness: Repo answers and GameFinder is alive. Upstream freshness is
  reported but never fails readiness (a Colonist outage must not drain pods).
  """
  def readiness do
    checks = %{database: database(), game_finder: if(GameFinder.alive?(), do: "up", else: "down")}
    ready? = checks.database == "ok" and checks.game_finder == "up"

    body = %{status: if(ready?, do: "ok", else: "error"), checks: checks}

    body =
      case GameFinder.upstream_status() do
        nil -> body
        snap -> Map.put(body, :upstream, snap)
      end

    {if(ready?, do: 200, else: 503), body}
  end

  defp database do
    case Ecto.Adapters.SQL.query(Colcoord.Repo, "SELECT 1", [], timeout: 2_000) do
      {:ok, _} -> "ok"
      _ -> "error"
    end
  rescue
    _ -> "error"
  catch
    :exit, _ -> "error"
  end
end
