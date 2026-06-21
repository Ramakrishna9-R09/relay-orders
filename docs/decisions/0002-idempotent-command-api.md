# ADR 0002: Require idempotency keys for writes

- Status: Accepted
- Date: 2026-06-21

## Context

Clients cannot reliably distinguish a lost response from a failed operation.
Retries without deduplication can create duplicate orders or transitions.

## Decision

Require `Idempotency-Key` on every mutating endpoint. Persist the tenant, key,
canonical request hash, resulting resource, and expiry.

## Consequences

- Network retries are safe.
- A key reused with different input returns a conflict.
- Records require retention and cleanup policy.
- The tenant is part of the uniqueness boundary.
