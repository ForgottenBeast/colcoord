# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs

alias Colcoord.{Repo, Settings}

# Ensure a default settings row exists
unless Repo.one(Settings) do
  Repo.insert!(%Settings{
    selected_modes: Jason.encode!([6, 7, 8, 9]),
    friends: Jason.encode!([]),
    auto_join: false
  })
end
