# Testing Strategy

Relay Orders uses layered tests so failures are caught at the smallest useful
boundary.

## Pure domain tests

`StateMachineTest` verifies named business examples such as the fulfillment
path and cancellation policy. These tests are fast, deterministic, and run
asynchronously.

## Property-based tests

`StateMachinePropertyTest` generates command sequences with StreamData and
checks invariants:

- accepted commands always change state;
- terminal states reject every command;
- rejected commands preserve the modeled state.

Property tests complement examples by exploring combinations that are easy to
miss manually.

## Transaction tests

`OrdersTest` runs against PostgreSQL through Ecto's SQL sandbox. It verifies:

- atomic order and event creation;
- safe idempotent replay;
- conflicting key rejection;
- invalid transition handling;
- tenant isolation.

These tests use the same database constraints and transaction behavior as the
production application.

## HTTP boundary tests

`OrderControllerTest` exercises authentication, request headers, response
codes, serialization, idempotency headers, and request correlation.

## Running tests

```powershell
mix test
mix test test/relay/orders/state_machine_property_test.exs
mix test test/relay/orders_test.exs
mix test test/relay_web/controllers/order_controller_test.exs
```

To reproduce a randomized failure, rerun the seed printed by ExUnit:

```powershell
mix test --seed 123456
```

## Contribution expectations

Bug fixes should first add a failing regression test. New workflow policy
should include an example test and, where applicable, an invariant property.
Database changes should be verified at the context layer rather than mocked.
