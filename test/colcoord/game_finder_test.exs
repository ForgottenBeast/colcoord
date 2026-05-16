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

    on_exit(fn ->
      :persistent_term.erase({MockHttpClient, :rooms})
    end)

    %{pid: pid}
  end

  describe "polling" do
    test "broadcasts rooms_update on poll", %{pid: pid} do
      Phoenix.PubSub.subscribe(Colcoord.PubSub, "games")

      :persistent_term.put({MockHttpClient, :rooms}, %{"rooms" => [
        %{"id" => "r1", "mode" => 6, "players" => ["alice"], "maxPlayers" => 4}
      ]})

      settings = Settings.get_or_create()
      settings |> Settings.changeset(%{selected_modes: Jason.encode!([6])}) |> Colcoord.Repo.update!()
      send(pid, :settings_changed)
      Process.sleep(50)

      GenServer.cast(pid, {:start_search, :auto})

      assert_receive {:rooms_update, rooms}, 1000
      assert length(rooms) == 1
      assert hd(rooms)["id"] == "r1"
    end

    test "broadcasts auto_join when match found and auto_join enabled", %{pid: pid} do
      Phoenix.PubSub.subscribe(Colcoord.PubSub, "games")

      :persistent_term.put({MockHttpClient, :rooms}, %{"rooms" => [
        %{"id" => "r1", "mode" => 6, "players" => ["alice"], "maxPlayers" => 4}
      ]})

      settings = Settings.get_or_create()
      settings
      |> Settings.changeset(%{selected_modes: Jason.encode!([6]), auto_join: true})
      |> Colcoord.Repo.update!()

      send(pid, :settings_changed)
      Process.sleep(50)

      GenServer.cast(pid, {:start_search, :auto})

      assert_receive {:auto_join, room}, 1000
      assert room["id"] == "r1"
    end

    test "stops polling on stop_search", %{pid: pid} do
      GenServer.cast(pid, {:start_search, :auto})
      GenServer.cast(pid, :stop_search)

      Phoenix.PubSub.subscribe(Colcoord.PubSub, "games")
      refute_receive _, 200
    end
  end

  describe "resume_search" do
    test "clears tab_opened_at and restarts polling", %{pid: pid} do
      Phoenix.PubSub.subscribe(Colcoord.PubSub, "games")

      :persistent_term.put({MockHttpClient, :rooms}, %{"rooms" => [
        %{"id" => "r2", "mode" => 6, "players" => [], "maxPlayers" => 4}
      ]})

      settings = Settings.get_or_create()
      settings |> Settings.changeset(%{selected_modes: Jason.encode!([6])}) |> Colcoord.Repo.update!()
      send(pid, :settings_changed)
      Process.sleep(50)

      GenServer.cast(pid, :resume_search)

      assert_receive {:rooms_update, _rooms}, 1000
    end
  end
end
