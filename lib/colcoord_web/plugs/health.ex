defmodule ColcoordWeb.Plugs.Health do
  @moduledoc """
  Kubernetes probe endpoints, served before parsers/session/router.

    * `GET /healthz` - liveness
    * `GET /readyz`  - readiness (reports upstream freshness, never fails on it)
  """
  @behaviour Plug
  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{method: m, request_path: "/healthz"} = conn, _) when m in ["GET", "HEAD"],
    do: respond(conn, Colcoord.Health.liveness())

  def call(%Plug.Conn{method: m, request_path: "/readyz"} = conn, _) when m in ["GET", "HEAD"],
    do: respond(conn, Colcoord.Health.readiness())

  def call(conn, _), do: conn

  defp respond(conn, {code, body}) do
    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("cache-control", "no-store")
    |> send_resp(code, Jason.encode!(body))
    |> halt()
  end
end
