defmodule Colcoord.ColonistEndpointTest do
  use ExUnit.Case, async: true

  @rooms_url "https://colonist.io/data/rooms.json"
  @retired_url "https://colonist.io/api/room-list.json"
  @runtime_files [
    "lib/colcoord/http_client.ex",
    "background.js"
  ]

  test "HTTP client publishes the current Colonist rooms data endpoint" do
    assert Colcoord.HttpClient.rooms_url() == @rooms_url
  end

  test "runtime code no longer references the retired room-list endpoint" do
    for path <- @runtime_files do
      source = File.read!(Path.expand(path, File.cwd!()))

      assert source =~ @rooms_url
      refute source =~ @retired_url
    end
  end
end
