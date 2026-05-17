defmodule Colcoord.RoomFilterTest do
  use ExUnit.Case, async: true

  alias Colcoord.RoomFilter

  @room1 %{
    "id" => "abc",
    "mode" => 6,
    "players" => [%{"username" => "alice", "icon" => 0, "isBot" => false}],
    "maxPlayers" => 4
  }
  @room2 %{
    "id" => "def",
    "mode" => 7,
    "players" => [
      %{"username" => "bob", "icon" => 0, "isBot" => false},
      %{"username" => "charlie", "icon" => 0, "isBot" => false}
    ],
    "maxPlayers" => 4
  }
  @room3 %{
    "id" => "ghi",
    "mode" => 8,
    "players" => [%{"username" => "dave", "icon" => 0, "isBot" => false}],
    "maxPlayers" => 2
  }
  @full_room %{
    "id" => "full",
    "mode" => 6,
    "players" =>
      for(n <- ["a", "b", "c", "d"], do: %{"username" => n, "icon" => 0, "isBot" => false}),
    "maxPlayers" => 4
  }

  describe "filter_and_sort/4" do
    test "filters by selected modes" do
      rooms = %{"rooms" => [@room1, @room2, @room3]}
      result = RoomFilter.filter_and_sort(rooms, [6], [], nil)

      assert length(result) == 1
      assert hd(result)["id"] == "abc"
    end

    test "filters out full rooms" do
      rooms = %{"rooms" => [@room1, @full_room]}
      result = RoomFilter.filter_and_sort(rooms, [6], [], nil)

      assert length(result) == 1
      assert hd(result)["id"] == "abc"
    end

    test "sorts rooms with friends first" do
      rooms = %{"rooms" => [@room1, @room2]}
      result = RoomFilter.filter_and_sort(rooms, [6, 7], ["bob"], nil)

      assert hd(result)["id"] == "def"
    end

    test "sorts by mode rank when no friends" do
      rooms = %{"rooms" => [@room2, @room1]}
      # mode 6 first in preference list
      result = RoomFilter.filter_and_sort(rooms, [6, 7], [], nil)

      assert hd(result)["id"] == "abc"
    end

    test "handles raw list (not wrapped in rooms key)" do
      result = RoomFilter.filter_and_sort([@room1], [6], [], nil)
      assert length(result) == 1
    end
  end

  describe "find_match/2" do
    test "returns first matching room" do
      filtered = RoomFilter.filter_and_sort(%{"rooms" => [@room1, @room2]}, [6, 7], [], nil)
      result = RoomFilter.find_match(filtered, nil)

      assert result["id"] == "abc"
    end

    test "skips last game id" do
      filtered = RoomFilter.filter_and_sort(%{"rooms" => [@room1, @room2]}, [6, 7], [], nil)
      result = RoomFilter.find_match(filtered, "abc")

      assert result["id"] == "def"
    end

    test "returns nil when no match" do
      filtered = RoomFilter.filter_and_sort(%{"rooms" => [@room1]}, [99], [], nil)
      result = RoomFilter.find_match(filtered, nil)

      assert result == nil
    end
  end
end
