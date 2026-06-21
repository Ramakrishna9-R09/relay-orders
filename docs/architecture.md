# Architecture

## Context

Relay Orders accepts order commands from clients that may timeout, retry, or
send concurrent requests. The system must preserve valid workflow state,
maintain tenant isolation, and never lose committed follow-up work.

## Components

```mermaid
flowchart LR
  Client["API client"] --> Gateway["Phoenix endpoint"]
  Gateway --> Auth["API key authentication"]
  Auth --> Limit["Tenant rate limit"]
  Limit --> Commands["Orders command boundary"]
  Commands --> State["Pure StateMachine"]
  Commands --> DB[("PostgreSQL")]
  DB --> Jobs["Oban workers"]
  Jobs --> External["Webhook / email / fulfillment"]
```

## Write transaction

```mermaid
sequenceDiagram
  participant C as Client
  participant A as Phoenix API
  participant O as Orders
  participant P as PostgreSQL
  participant W as Oban

  C->>A: Command + Idempotency-Key
  A->>O: Authenticated tenant command
  O->>P: Find existing idempotency record
  alt Existing matching request
    P-->>O: Existing order
    O-->>C: Idempotent replay
  else New request
    O->>P: BEGIN
    O->>P: SELECT order FOR UPDATE
    O->>O: Pure state transition
    O->>P: Update order
    O->>P: Append audit event
    O->>P: Insert Oban job
    O->>P: Insert idempotency record
    O->>P: COMMIT
    W->>P: Claim durable job
    O-->>C: Updated order
  end
```

## Reliability properties

- Duplicate requests with the same body return the original resource.
- Reusing an idempotency key with different input is rejected.
- Row locks serialize commands against one order.
- Event sequence numbers match aggregate versions.
- State, event, job, and idempotency record commit atomically.
- Failed workers retry independently without rolling back business state.

## Boundaries

`Relay.Orders.StateMachine` owns workflow policy and is pure.

`Relay.Orders` coordinates persistence and transactions.

`RelayWeb` owns HTTP authentication, validation, serialization, and status
codes.

`Relay.Workers` owns asynchronous integration boundaries.

This separation keeps domain logic testable while allowing infrastructure to
evolve independently.
