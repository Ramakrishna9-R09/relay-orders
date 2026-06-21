# ADR 0003: Serialize order commands with row locks

- Status: Accepted
- Date: 2026-06-21

## Context

Two clients may issue commands for the same order concurrently. Without
serialization, both transactions could read the same version, accept
incompatible transitions, or attempt to append the same event sequence.

Application-level locks would only coordinate requests handled by one BEAM
node and would become incorrect after horizontal scaling.

## Decision

Load an order with PostgreSQL `SELECT ... FOR UPDATE` inside the command
transaction. Evaluate the pure state transition only after the row lock is
held.

## Consequences

- Commands for one order execute serially across all application nodes.
- Commands for different orders still proceed concurrently.
- Event sequence and aggregate version remain aligned.
- Lock duration must stay short; external calls are forbidden inside the
  transaction.
- Deadlock and lock-wait metrics should be monitored as throughput grows.
