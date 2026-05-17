defmodule Colcoord.RoomFilter do
  @moduledoc false

  def filter_and_sort(response, selected_modes, friends_list, _last_game_id) do
    rooms = extract_rooms(response)
    mode_rank = selected_modes |> Enum.with_index() |> Map.new()

    rooms
    |> filter(selected_modes)
    |> Enum.sort_by(fn room ->
      players = room["players"] || []
      friend_count = Enum.count(players, fn p -> p["username"] in friends_list end)
      mode_position = Map.get(mode_rank, room["mode"], 999)
      {-friend_count, mode_position}
    end)
  end

  def find_match(response, selected_modes, friends_list, last_game_id) do
    response
    |> filter_and_sort(selected_modes, friends_list, last_game_id)
    |> Enum.reject(fn room -> room["id"] == last_game_id end)
    |> List.first()
  end

  defp extract_rooms(%{"rooms" => rooms}) when is_list(rooms), do: rooms
  defp extract_rooms(rooms) when is_list(rooms), do: rooms
  defp extract_rooms(_), do: []

  defp filter(rooms, selected_modes) do
    Enum.filter(rooms, fn room ->
      players = room["players"] || []
      max_players = room["maxPlayers"] || 0
      mode = room["mode"]

      length(players) < max_players and mode in selected_modes
    end)
  end
end
