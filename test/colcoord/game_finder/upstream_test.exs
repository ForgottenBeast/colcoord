defmodule Colcoord.GameFinder.UpstreamTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Colcoord.GameFinder.Upstream

  @stale_after_ms Upstream.stale_after_ms()
  @warn_interval_ms Upstream.warn_interval_ms()

  describe "unit" do
    test "new state is :never with zero failures" do
      assert %{status: :never, seconds_since_success: nil, consecutive_failures: 0} =
               Upstream.snapshot(Upstream.new(), 5_000)
    end

    test "success makes it fresh, then stale after the threshold" do
      {s, nil} = Upstream.record(Upstream.new(), :ok, 1_000)
      assert %{status: :fresh, seconds_since_success: 0} = Upstream.snapshot(s, 1_000)
      assert %{status: :fresh} = Upstream.snapshot(s, 1_000 + @stale_after_ms)

      assert %{status: :stale, seconds_since_success: secs} =
               Upstream.snapshot(s, 1_001 + @stale_after_ms)

      assert secs == div(@stale_after_ms, 1000)
    end

    test "first failure warns, repeats are rate limited, recovery is reported once" do
      s = Upstream.new()
      {s, :warn} = Upstream.record(s, :error, 0)
      {s, nil} = Upstream.record(s, :error, 1_000)
      {s, nil} = Upstream.record(s, :error, @warn_interval_ms - 1)
      {s, :warn} = Upstream.record(s, :error, @warn_interval_ms)
      assert %{consecutive_failures: 4, status: :never} = Upstream.snapshot(s, @warn_interval_ms)
      {s, :recovered} = Upstream.record(s, :ok, @warn_interval_ms + 1)
      {s, nil} = Upstream.record(s, :ok, @warn_interval_ms + 2)

      assert %{consecutive_failures: 0, status: :fresh} =
               Upstream.snapshot(s, @warn_interval_ms + 2)
    end

    test "failure after a success warns immediately" do
      {s, nil} = Upstream.record(Upstream.new(), :ok, 0)
      {_s, :warn} = Upstream.record(s, :error, 10)
    end
  end

  describe "properties" do
    defp events do
      list_of(
        tuple({member_of([:ok, :error]), integer(0..120_000)}),
        max_length: 60
      )
    end

    defp run(events) do
      {_t, final, trace} =
        Enum.reduce(events, {0, Upstream.new(), []}, fn {kind, dt}, {t, s, acc} ->
          t = t + dt
          {s2, action} = Upstream.record(s, kind, t)
          {t, s2, [{kind, t, action, s2} | acc]}
        end)

      {final, Enum.reverse(trace)}
    end

    property "consecutive_failures equals the trailing run of errors" do
      check all(evs <- events()) do
        {final, _} = run(evs)

        trailing =
          evs |> Enum.reverse() |> Enum.take_while(fn {k, _} -> k == :error end) |> length()

        assert Upstream.snapshot(final, 0 + Enum.sum(Enum.map(evs, &elem(&1, 1)))).consecutive_failures ==
                 trailing
      end
    end

    property "classification matches time since last success" do
      check all(evs <- events(), extra <- integer(0..200_000)) do
        {final, trace} = run(evs)
        now = (trace |> List.last({nil, 0, nil, nil}) |> elem(1)) + extra
        now = max(now, trace |> Enum.map(&elem(&1, 1)) |> Enum.max(fn -> 0 end))
        snap = Upstream.snapshot(final, now)

        last_ok =
          trace |> Enum.filter(fn {k, _, _, _} -> k == :ok end) |> List.last()

        case last_ok do
          nil ->
            assert snap.status == :never and snap.seconds_since_success == nil

          {_, t, _, _} ->
            age = now - t
            assert snap.seconds_since_success == div(age, 1000)
            assert snap.status == if(age <= @stale_after_ms, do: :fresh, else: :stale)
        end
      end
    end

    property "warn rate limit and recovery invariants" do
      check all(evs <- events()) do
        {_final, trace} = run(evs)

        # walk the trace tracking previous state
        Enum.reduce(trace, {:ok_or_start, nil, nil}, fn {kind, t, action, _s},
                                                        {prev, last_warn, _} ->
          case {kind, prev} do
            {:ok, :failing} ->
              assert action == :recovered

            {:ok, _} ->
              assert action == nil

            {:error, p} when p != :failing ->
              assert action == :warn

            {:error, :failing} ->
              if t - last_warn >= @warn_interval_ms,
                do: assert(action == :warn),
                else: assert(action == nil)
          end

          last_warn = if action == :warn, do: t, else: last_warn
          {if(kind == :error, do: :failing, else: :ok_or_start), last_warn, nil}
        end)
      end
    end

    property "warnings during a failure streak are at least one interval apart" do
      check all(evs <- events()) do
        {_final, trace} = run(evs)

        trace
        |> Enum.chunk_by(fn {k, _, _, _} -> k end)
        |> Enum.filter(fn [{k, _, _, _} | _] -> k == :error end)
        |> Enum.each(fn streak ->
          times = for {_, t, :warn, _} <- streak, do: t

          times
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.each(fn [a, b] -> assert b - a >= @warn_interval_ms end)
        end)
      end
    end
  end
end
