defmodule Relay.Orders.StateMachine do
  @moduledoc """
  Pure order workflow.

  Keeping transition rules free of database and process concerns makes the
  business model deterministic, exhaustively testable, and easy to replay.
  """

  @type status :: :pending | :paid | :packed | :shipped | :delivered | :cancelled
  @type command :: :pay | :pack | :ship | :deliver | :cancel

  @transitions %{
    {:pending, :pay} => :paid,
    {:pending, :cancel} => :cancelled,
    {:paid, :pack} => :packed,
    {:paid, :cancel} => :cancelled,
    {:packed, :ship} => :shipped,
    {:shipped, :deliver} => :delivered
  }

  @spec transition(status(), command()) ::
          {:ok, status()} | {:error, {:invalid_transition, status(), command()}}
  def transition(status, command) do
    case Map.fetch(@transitions, {status, command}) do
      {:ok, next_status} -> {:ok, next_status}
      :error -> {:error, {:invalid_transition, status, command}}
    end
  end

  def commands, do: [:pay, :pack, :ship, :deliver, :cancel]
end
