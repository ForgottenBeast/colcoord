defmodule Colcoord.GameFinderTest do
  use Colcoord.DataCase, async: false

  alias Colcoord.{GameFinder, Settings}

  defmodule MockHttpClient do
    def fetch_rooms do
      case :persistent_term.get({__MODULE__, :rooms}, :not_set) do
        :not_set -> {:ok, %{"rooms" => []}}
        rooms -> {:ok, rooms}
      end
    end
  end

  setup do
    Settings.get_or_create()

    # Start a separate instance (not the named one)
    {:ok, pid} =
      GenServer.start_link(GameFinder, [http_client: MockHttpClient], [])

    # Allow the GenServer process to use the test's sandbox DB connection
    Ecto.Adapters.SQL.Sandbox.allow(Colcoord.Repo, self(), pid)

    on_exit(fn ->
      :persistent_term.erase({MockHttpClient, :rooms})
    end)

    %{pid: pid}
  end

  defp set_settings(attrs) do
    Settings.get_or_create()
    |> Settings.changeset(attrs)
    |> Colcoord.Repo.update!()
  end

  defp sync_settings(pid) do
    GenServer.cast(pid, :settings_changed)
    # :sys.get_state drains the GenServer mailbox before returning
    :sys.get_state(pid)
  end

  describe "polling" do
    test "broadcasts rooms_update on poll", %{pid: pid} do
      Phoenix.PubSub.subscribe(Colcoord.PubSub, "games")

      :persistent_term.put({MockHttpClient, :rooms}, %{
        "rooms" => [
          %{
            "id" => "r1",
            "mode" => 6,
            "players" => [%{"username" => "alice", "icon" => 0, "isBot" => false}],
            "maxPlayers" => 4
          }
        ]
      })

      set_settings(%{selected_modes: Jason.encode!([6])})
      sync_settings(pid)

      send(pid, :poll)

      assert_receive {:rooms_update, rooms}, 1000
      assert length(rooms) == 1
      assert hd(rooms)["id"] == "r1"
    end

    test "broadcasts auto_join when match found and auto_join enabled", %{pid: pid} do
      Phoenix.PubSub.subscribe(Colcoord.PubSub, "games")

      :persistent_term.put({MockHttpClient, :rooms}, %{
        "rooms" => [
          %{
            "id" => "r1",
            "mode" => 6,
            "players" => [%{"username" => "alice", "icon" => 0, "isBot" => false}],
            "maxPlayers" => 4
          }
        ]
      })

      set_settings(%{selected_modes: Jason.encode!([6]), auto_join: true})
      sync_settings(pid)

      send(pid, :poll)

      assert_receive {:auto_join, room}, 1000
      assert room["id"] == "r1"
    end

    test "stops polling after auto_join match", %{pid: pid} do
      Phoenix.PubSub.subscribe(Colcoord.PubSub, "games")

      :persistent_term.put({MockHttpClient, :rooms}, %{
        "rooms" => [
          %{
            "id" => "r1",
            "mode" => 6,
            "players" => [%{"username" => "alice", "icon" => 0, "isBot" => false}],
            "maxPlayers" => 4
          }
        ]
      })

      set_settings(%{selected_modes: Jason.encode!([6]), auto_join: true})
      sync_settings(pid)

      send(pid, :poll)
      assert_receive {:auto_join, _room}, 1000

      # After auto_join, polling should be stopped
      send(pid, :poll)
      refute_receive {:auto_join, _}, 200
    end
  end

  describe "resume_search" do
    test "restarts polling after auto_join", %{pid: pid} do
      Phoenix.PubSub.subscribe(Colcoord.PubSub, "games")

      :persistent_term.put({MockHttpClient, :rooms}, %{
        "rooms" => [
          %{"id" => "r2", "mode" => 6, "players" => [], "maxPlayers" => 4}
        ]
      })

      set_settings(%{selected_modes: Jason.encode!([6])})
      sync_settings(pid)

      GenServer.cast(pid, :resume_search)

      assert_receive {:rooms_update, _rooms}, 1000
    end
  end

  describe "get_rooms" do
    test "returns last fetched rooms", %{pid: pid} do
      :persistent_term.put({MockHttpClient, :rooms}, %{
        "rooms" => [
          %{"id" => "r1", "mode" => 6, "players" => [], "maxPlayers" => 4}
        ]
      })

      set_settings(%{selected_modes: Jason.encode!([6])})
      sync_settings(pid)

      send(pid, :poll)
      # Drain mailbox to ensure poll has been processed
      :sys.get_state(pid)

      rooms = GenServer.call(pid, :get_rooms)
      assert length(rooms) == 1
      assert hd(rooms)["id"] == "r1"
    end
  end
end
