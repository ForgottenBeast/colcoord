defmodule ColcoordWeb.Plugs.HealthTest do
  use ColcoordWeb.ConnCase, async: false

  alias Colcoord.GameFinder

  defmodule OkClient do
    def fetch_rooms, do: {:ok, %{"rooms" => []}}
  end

  defmodule DownClient do
    def fetch_rooms, do: {:error, :econnrefused}
  end

  defp start_finder(client) do
    start_supervised!({GameFinder, http_client: client})
    :sys.get_state(GameFinder)
  end

  describe "GET /healthz" do
    test "503 when GameFinder is not running", %{conn: conn} do
      conn = get(conn, "/healthz")
      assert %{"status" => "error", "checks" => %{"game_finder" => "down"}} = json_response(conn, 503)
    end

    test "200 JSON when GameFinder is alive, even if upstream is failing", %{conn: conn} do
      start_finder(DownClient)
      conn = get(conn, "/healthz")
      assert %{"status" => "ok", "checks" => %{"game_finder" => "up"}} = json_response(conn, 200)
      assert [ct] = get_resp_header(conn, "content-type")
      assert ct =~ "application/json"
      assert get_resp_header(conn, "cache-control") == ["no-store"]
    end

    test "does not touch the session or router", %{conn: conn} do
      start_finder(OkClient)
      conn = get(conn, "/healthz")
      assert conn.halted
      assert get_resp_header(conn, "set-cookie") == []
    end
  end

  describe "GET /readyz" do
    test "503 when GameFinder is not running", %{conn: conn} do
      conn = get(conn, "/readyz")
      assert %{"status" => "error", "checks" => %{"game_finder" => "down"}} = json_response(conn, 503)
    end

    test "200 with fresh upstream", %{conn: conn} do
      start_finder(OkClient)
      body = conn |> get("/readyz") |> json_response(200)

      assert %{
               "status" => "ok",
               "checks" => %{"database" => "ok", "game_finder" => "up"},
               "upstream" => %{
                 "status" => "fresh",
                 "seconds_since_success" => secs,
                 "consecutive_failures" => 0
               }
             } = body

      assert is_integer(secs) and secs >= 0
    end

    test "staleness / failures do NOT fail readiness", %{conn: conn} do
      start_finder(DownClient)
      body = conn |> get("/readyz") |> json_response(200)

      assert %{
               "status" => "ok",
               "upstream" => %{
                 "status" => "never",
                 "seconds_since_success" => nil,
                 "consecutive_failures" => n
               }
             } = body

      assert n >= 1
    end
  end

  describe "force_ssl" do
    test "plain HTTP probes are not redirected when paths are excluded" do
      prod = Config.Reader.read!("config/prod.exs", env: :prod)
      ssl = prod[:colcoord][ColcoordWeb.Endpoint][:force_ssl]
      opts = Plug.SSL.init(ssl)

      for path <- ["/healthz", "/readyz"] do
        conn = Plug.SSL.call(Plug.Test.conn(:get, path), opts)
        refute conn.halted, "#{path} must bypass Plug.SSL"
      end

      conn = Plug.SSL.call(Plug.Test.conn(:get, "/"), opts)
      assert conn.status == 301
    end
  end
end
