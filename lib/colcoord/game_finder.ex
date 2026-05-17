defmodule Colcoord.GameFinder do
  @moduledoc false
  use GenServer

  alias Colcoord.{HttpClient, RoomFilter, Settings}

  @poll_interval 1_000
  @pubsub Colcoord.PubSub
  @topic "games"

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def resume_search do
    GenServer.cast(__MODULE__, :resume_search)
  end

  def notify_settings_changed do
    GenServer.cast(__MODULE__, :settings_changed)
  end

  def subscribe do
    Phoenix.PubSub.subscribe(@pubsub, @topic)
  end

  def get_rooms do
    GenServer.call(__MODULE__, :get_rooms)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    http_client = Keyword.get(opts, :http_client, HttpClient)
    settings = Settings.get_or_create()

    state = %{
      settings: settings,
      last_game_id: settings.last_game_found,
      polling: true,
      http_client: http_client,
      error_count: 0,
      last_rooms: []
    }

    # Start polling immediately so rooms are displayed as soon as someone connects
    schedule_poll(0)

    {:ok, state}
  end

  @impl true
  def handle_call(:get_rooms, _from, state) do
    {:reply, state.last_rooms, state}
  end

  @impl true
  def handle_cast(:resume_search, state) do
    state = %{state | polling: true}
    schedule_poll(0)
    {:noreply, state}
  end

  def handle_cast(:settings_changed, state) do
    settings = Settings.get_or_create()
    schedule_poll(0)
    {:noreply, %{state | settings: settings}}
  end

  @impl true
  def handle_info(:poll, %{polling: false} = state) do
    {:noreply, state}
  end

  def handle_info(:poll, state) do
    case state.http_client.fetch_rooms() do
      {:ok, body} ->
        handle_rooms(body, %{state | error_count: 0})

      {:error, _reason} ->
        error_count = state.error_count + 1
        backoff = HttpClient.backoff_ms(error_count)
        schedule_poll(backoff)
        {:noreply, %{state | error_count: error_count}}
    end
  end

  def handle_info({:client_rooms, rooms}, state) do
    handle_rooms(rooms, state)
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private

  defp handle_rooms(body, state) do
    settings = state.settings
    selected_modes = Settings.decode_modes(settings)
    friends_list = Settings.decode_friends(settings)

    filtered = RoomFilter.filter_and_sort(body, selected_modes, friends_list, state.last_game_id)
    state = %{state | last_rooms: filtered}
    broadcast({:rooms_update, filtered})

    if settings.auto_join do
      case RoomFilter.find_match(filtered, state.last_game_id) do
        nil ->
          schedule_poll(@poll_interval)
          {:noreply, state}

        room ->
          broadcast({:auto_join, room})

          new_state = %{
            state
            | last_game_id: room["id"],
              polling: false
          }

          persist_last_game(room["id"])
          {:noreply, new_state}
      end
    else
      schedule_poll(@poll_interval)
      {:noreply, state}
    end
  end

  defp schedule_poll(delay) do
    Process.send_after(self(), :poll, delay)
  end

  defp broadcast(message) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, message)
  end

  defp persist_last_game(game_id) do
    settings = Settings.get_or_create()

    settings
    |> Settings.changeset(%{last_game_found: game_id})
    |> Colcoord.Repo.update()
  end
end
