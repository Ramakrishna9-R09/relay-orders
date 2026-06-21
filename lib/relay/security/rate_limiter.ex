defmodule Relay.Security.RateLimiter do
  @moduledoc """
  Lightweight per-tenant fixed-window limiter backed by an atomic ETS counter.

  Distributed deployments should replace this with a shared limiter at the
  edge or in Redis; this protects each node from abusive bursts.
  """

  use GenServer

  @table __MODULE__
  @window_seconds 60
  @cleanup_interval :timer.minutes(5)

  def start_link(_options), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def allow?(tenant_id, limit) when is_integer(limit) and limit > 0 do
    bucket = div(System.system_time(:second), @window_seconds)
    count = :ets.update_counter(@table, {tenant_id, bucket}, {2, 1}, {{tenant_id, bucket}, 0})
    count <= limit
  end

  @impl true
  def init(:ok) do
    :ets.new(@table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    current_bucket = div(System.system_time(:second), @window_seconds)

    :ets.select_delete(@table, [
      {{{:"$1", :"$2"}, :"$3"}, [{:<, :"$2", current_bucket - 1}], [true]}
    ])

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup, do: Process.send_after(self(), :cleanup, @cleanup_interval)
end
