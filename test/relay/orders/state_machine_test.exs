defmodule Relay.Orders.StateMachineTest do
  use ExUnit.Case, async: true

  alias Relay.Orders.StateMachine

  test "models the happy path as pure transitions" do
    assert {:ok, :paid} = StateMachine.transition(:pending, :pay)
    assert {:ok, :packed} = StateMachine.transition(:paid, :pack)
    assert {:ok, :shipped} = StateMachine.transition(:packed, :ship)
    assert {:ok, :delivered} = StateMachine.transition(:shipped, :deliver)
  end

  test "rejects transitions that violate the workflow" do
    assert {:error, {:invalid_transition, :pending, :ship}} =
             StateMachine.transition(:pending, :ship)
  end
end
