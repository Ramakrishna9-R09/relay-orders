# API Guide

Relay Orders uses Bearer API keys for tenant authentication and requires an
idempotency key for every write.

## Request headers

```text
Authorization: Bearer <tenant-api-key>
Idempotency-Key: <unique-client-operation-id>
X-Request-ID: <optional-correlation-id>
Content-Type: application/json
```

Use a stable idempotency key when retrying the same operation. Generate a new
key for a logically new operation.

## Workflow

```text
pending -> paid -> packed -> shipped -> delivered
    |         |
    +------ cancelled
```

Commands that do not match the current state return `409 Conflict`.

## Error envelope

All expected API errors use:

```json
{
  "error": {
    "code": "invalid_transition",
    "message": "Cannot ship an order in pending status."
  }
}
```

Validation errors additionally include field-level details.

## Idempotent replay

A replayed request returns the original resource and:

```text
Idempotent-Replayed: true
```

Reusing the same key with different request content returns
`409 idempotency_key_reused`.

## Correlation

Clients may supply `X-Request-ID`. Relay returns it in the response and stores
it on the immutable audit event, allowing an API request to be followed into
database history and asynchronous processing.

The full machine-readable contract is available in
[`openapi.yaml`](openapi.yaml).
