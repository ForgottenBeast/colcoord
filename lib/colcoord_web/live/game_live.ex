defmodule ColcoordWeb.GameLive do
  use ColcoordWeb, :live_view

  alias Colcoord.{GameFinder, Settings}

  @mode_map Settings.mode_map()

  @impl true
  def mount(_params, _session, socket) do
    rooms =
      if connected?(socket) do
        GameFinder.subscribe()
        GameFinder.get_rooms()
      else
        []
      end

    settings = Settings.get_or_create()

    socket =
      socket
      |> assign(:rooms, rooms)
      |> assign(:settings, settings)
      |> assign(:selected_modes, Settings.decode_modes(settings))
      |> assign(:friends, Settings.decode_friends(settings))
      |> assign(:auto_join, settings.auto_join)
      |> assign(:show_fallback_link, false)
      |> assign(:fallback_url, nil)
      |> assign(:error, nil)
      |> assign(:games_analyzed, 0)
      |> assign(:mode_map, @mode_map)
      |> assign(:friend_input, "")

    {:ok, socket}
  end

  @impl true
  def handle_info({:rooms_update, rooms}, socket) do
    {:noreply, assign(socket, rooms: rooms, games_analyzed: socket.assigns.games_analyzed + length(rooms))}
  end

  def handle_info({:auto_join, room}, socket) do
    url = "https://colonist.io/#" <> room["id"]
    {:noreply, push_event(socket, "open_game", %{url: url})}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_mode", %{"code" => code_str}, socket) do
    code = String.to_integer(code_str)
    modes = socket.assigns.selected_modes

    new_modes =
      if code in modes,
        do: List.delete(modes, code),
        else: modes ++ [code]

    persist_and_notify(socket, %{selected_modes: Settings.encode_modes(new_modes)})
    {:noreply, assign(socket, selected_modes: new_modes)}
  end

  def handle_event("add_friend", %{"name" => name}, socket) do
    name = String.trim(name)

    if name == "" do
      {:noreply, socket}
    else
      friends = socket.assigns.friends
      new_friends = if name in friends, do: friends, else: friends ++ [name]
      persist_and_notify(socket, %{friends: Settings.encode_friends(new_friends)})
      {:noreply, assign(socket, friends: new_friends, friend_input: "")}
    end
  end

  def handle_event("remove_friend", %{"name" => name}, socket) do
    new_friends = List.delete(socket.assigns.friends, name)
    persist_and_notify(socket, %{friends: Settings.encode_friends(new_friends)})
    {:noreply, assign(socket, friends: new_friends)}
  end

  def handle_event("toggle_auto_join", _params, socket) do
    new_val = !socket.assigns.auto_join
    persist_and_notify(socket, %{auto_join: new_val})
    {:noreply, assign(socket, auto_join: new_val)}
  end

  def handle_event("open_game", %{"id" => id}, socket) do
    url = "https://colonist.io/#" <> id
    {:noreply, push_event(socket, "open_game", %{url: url})}
  end

  def handle_event("tab_closed", _params, socket) do
    GameFinder.resume_search()
    {:noreply, socket}
  end

  def handle_event("popup_blocked", %{"url" => url}, socket) do
    {:noreply, assign(socket, show_fallback_link: true, fallback_url: url)}
  end

  def handle_event("update_friend_input", %{"value" => val}, socket) do
    {:noreply, assign(socket, friend_input: val)}
  end

  defp persist_and_notify(socket, attrs) do
    settings = socket.assigns.settings

    settings
    |> Settings.changeset(attrs)
    |> Colcoord.Repo.update!()

    GameFinder.notify_settings_changed()
  end
end
