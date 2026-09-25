defmodule Colcoord.HttpClient do
  @moduledoc false

  @url "https://colonist.io/data/rooms.json"
  @timeout 5_000
  @max_backoff 16_000

  @user_agent "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"

  def rooms_url, do: @url

  def fetch_rooms(opts \\ []) do
    url = Keyword.get(opts, :url, rooms_url())

    case Req.get(url,
           headers: [{"user-agent", @user_agent}],
           receive_timeout: @timeout,
           connect_options: [timeout: @timeout]
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def backoff_ms(attempt) do
    min(1_000 * Integer.pow(2, attempt), @max_backoff)
  end
end
