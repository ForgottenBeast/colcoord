defmodule Colcoord.Repo do
  use Ecto.Repo,
    otp_app: :colcoord,
    adapter: Ecto.Adapters.SQLite3
end
