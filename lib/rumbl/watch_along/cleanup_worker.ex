defmodule Rumbl.WatchAlong.CleanupWorker do
  @moduledoc """
  Periodically prunes inactive/stale watch rooms.
  """

  use GenServer

  alias Rumbl.WatchAlong

  @interval_ms :timer.minutes(1)
  @ttl_minutes 5

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    _ = WatchAlong.cleanup_unused_or_inactive_rooms(@ttl_minutes)
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @interval_ms)
  end
end
