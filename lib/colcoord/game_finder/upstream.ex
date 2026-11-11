defmodule Colcoord.GameFinder.Upstream do
  @moduledoc """
  Pure bookkeeping for the Colonist rooms upstream: last success, consecutive
  failures, and which transitions deserve a log line.

  All times are monotonic milliseconds supplied by the caller.
  """

  @stale_after_ms 30_000
  @warn_interval_ms 60_000

  defstruct last_success: nil, failures: 0, last_warn: nil

  def stale_after_ms, do: @stale_after_ms
  def warn_interval_ms, do: @warn_interval_ms

  def new, do: %__MODULE__{}

  @doc """
  Records a fetch outcome. Returns `{state, action}` where action is `:warn`
  (log a failure), `:recovered` (first success after failures) or `nil`.
  """
  def record(%__MODULE__{} = s, :ok, now) do
    action = if s.failures > 0, do: :recovered
    {%{s | last_success: now, failures: 0, last_warn: nil}, action}
  end

  def record(%__MODULE__{} = s, :error, now) do
    s = %{s | failures: s.failures + 1}

    if s.last_warn == nil or now - s.last_warn >= @warn_interval_ms do
      {%{s | last_warn: now}, :warn}
    else
      {s, nil}
    end
  end

  def snapshot(%__MODULE__{} = s, now) do
    case s.last_success do
      nil ->
        %{status: :never, seconds_since_success: nil, consecutive_failures: s.failures}

      t ->
        age = now - t

        %{
          status: if(age <= @stale_after_ms, do: :fresh, else: :stale),
          seconds_since_success: div(age, 1000),
          consecutive_failures: s.failures
        }
    end
  end
end
