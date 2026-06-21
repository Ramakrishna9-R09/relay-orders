defmodule Relay.Workers.OrderEventWorker do
  @moduledoc """
  Durable side-effect boundary.

  Oban inserts this job in the same PostgreSQL transaction as the order event,
  so committed business state cannot lose its follow-up work.
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 10,
    unique: [period: 86_400, fields: [:args], keys: [:event_id]]

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"event_id" => event_id, "event_type" => event_type}}) do
    Logger.info("dispatching order event",
      event_id: event_id,
      event_type: event_type
    )

    :ok
  end
end
