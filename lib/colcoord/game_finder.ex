defmodule Colcoord.GameFinder do
  @moduledoc false
  use GenServer
  require Logger

  alias Colcoord.GameFinder.Upstream
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

  def alive? do
    case Process.whereis(__MODULE__) do
      nil -> false
      pid -> Process.alive?(pid)
    end
  end

  @doc """
  Upstream fetch health snapshot (`:status`, `:seconds_since_success`,
  `:consecutive_failures`), or nil if no GameFinder has published one. Reads
  lock-free `:atomics` so it never blocks behind a slow (up to 5s) fetch.
  """
  def upstream_status do
    case :persistent_term.get({__MODULE__, :upstream}, nil) do
      nil ->
        nil

      ref ->
        last_success = if :atomics.get(ref, 1) == 1, do: :atomics.get(ref, 2)
        upstream = %Upstream{last_success: last_success, failures: :atomics.get(ref, 3)}
        Upstream.snapshot(upstream, now())
    end
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
      last_rooms: [],
      upstream: Upstream.new()
    }

    :persistent_term.put({__MODULE__, :upstream}, :atomics.new(3, signed: true))
    publish_upstream(state)

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
        state = track(state, :ok, nil)
        handle_rooms(body, %{state | error_count: 0})

      {:error, reason} ->
        state = track(state, :error, reason)
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

  defp now, do: System.monotonic_time(:millisecond)

  defp track(state, outcome, reason) do
    {upstream, action} = Upstream.record(state.upstream, outcome, now())
    state = %{state | upstream: upstream}
    publish_upstream(state)

    case action do
      :warn ->
        Logger.warning(
          "rooms fetch failing (#{upstream.failures} consecutive): #{inspect(reason)}"
        )

      :recovered ->
        Logger.info("rooms fetch recovered")

      nil ->
        :ok
    end

    state
  end

  defp publish_upstream(state) do
    ref = :persistent_term.get({__MODULE__, :upstream})
    %Upstream{last_success: ts, failures: failures} = state.upstream
    :atomics.put(ref, 2, ts || 0)
    :atomics.put(ref, 3, failures)
    :atomics.put(ref, 1, if(ts, do: 1, else: 0))
  end

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
