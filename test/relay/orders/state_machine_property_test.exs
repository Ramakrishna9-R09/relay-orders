defmodule Relay.Orders.StateMachinePropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Relay.Orders.StateMachine

  @initial_status :pending
  @terminal_statuses [:delivered, :cancelled]

  property "accepted commands always move to a different state" do
    check all(commands <- list_of(member_of(StateMachine.commands()), max_length: 30)) do
      {_status, transitions} = run_commands(commands)

      assert Enum.all?(transitions, fn {before, after_status} ->
               before != after_status
             end)
    end
  end

  property "terminal states reject every command" do
    check all(
            status <- member_of(@terminal_statuses),
            command <- member_of(StateMachine.commands())
          ) do
      assert {:error, {:invalid_transition, ^status, ^command}} =
               StateMachine.transition(status, command)
    end
  end

  property "rejected commands leave the modeled state unchanged" do
    check all(commands <- list_of(member_of(StateMachine.commands()), max_length: 30)) do
      {_status, attempts} = execute(commands)

      assert Enum.all?(attempts, fn
               {:accepted, before, after_status} -> before != after_status
               {:rejected, before, after_status} -> before == after_status
             end)
    end
  end

  defp run_commands(commands) do
    Enum.reduce(commands, {@initial_status, []}, fn command, {status, transitions} ->
      case StateMachine.transition(status, command) do
        {:ok, next_status} -> {next_status, [{status, next_status} | transitions]}
        {:error, _reason} -> {status, transitions}
      end
    end)
  end

  defp execute(commands) do
    Enum.reduce(commands, {@initial_status, []}, fn command, {status, attempts} ->
      case StateMachine.transition(status, command) do
        {:ok, next_status} ->
          {next_status, [{:accepted, status, next_status} | attempts]}

        {:error, _reason} ->
          {status, [{:rejected, status, status} | attempts]}
      end
    end)
  end
end
