# Roadmap

## Near term

- Outbound webhook destinations and HMAC signatures
- Delivery attempts, exponential backoff, and dead-letter inspection
- API key creation, rotation, expiry, and revocation
- Cursor pagination and order filtering
- Property-based tests for the state machine

## Operational maturity

- OpenTelemetry traces and Prometheus metrics
- SLOs for command latency, error rate, and job lag
- Global rate limiting at the edge
- Backup and restore runbook
- Load and failure-injection testing

## Scale path

- Read replicas for query-heavy workloads
- Partition audit events by organization/time
- Dedicated outbox relay for external event streaming
- Region-aware deployment and tenant placement
