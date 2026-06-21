# ADR 0001: Use transactional Oban jobs

- Status: Accepted
- Date: 2026-06-21

## Context

An accepted order command may need to trigger email, webhooks, inventory, or
fulfillment. Updating PostgreSQL and then publishing to an external broker
creates a dual-write failure window.

## Decision

Insert an Oban job inside the same `Ecto.Multi` transaction as the order state,
audit event, and idempotency record.

## Consequences

- Committed state always has durable follow-up work.
- PostgreSQL is the initial queue dependency.
- Workers gain retry, scheduling, uniqueness, and operational inspection.
- High-volume event streaming may later require an outbox relay or broker.
