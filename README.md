# Relay Orders

[![CI](https://github.com/Ramakrishna9-R09/relay-orders/actions/workflows/ci.yml/badge.svg)](https://github.com/Ramakrishna9-R09/relay-orders/actions/workflows/ci.yml)
[![Elixir](https://img.shields.io/badge/Elixir-1.20-4B275F?logo=elixir)](https://elixir-lang.org/)
[![Phoenix](https://img.shields.io/badge/Phoenix-1.8-FD4F00?logo=phoenixframework)](https://www.phoenixframework.org/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Relay is a production-oriented, multi-tenant order orchestration API built with
Elixir, Phoenix, PostgreSQL, and Oban. It is intentionally designed around the
failure modes that make distributed backends difficult: duplicate requests,
concurrent commands, lost background work, tenant data leakage, and incomplete
audit trails.

This is not a CRUD tutorial. It is a compact demonstration of functional domain
modeling and OTP-backed operational reliability.

> Portfolio focus: resilient backend design, functional domain modeling,
> transactional consistency, API reliability, and production operations.

## Repository guide

| Area | Purpose |
| --- | --- |
| [`lib/relay/orders`](lib/relay/orders) | Domain schemas and pure order state machine |
| [`lib/relay/orders.ex`](lib/relay/orders.ex) | Transactional application/command boundary |
| [`lib/relay_web`](lib/relay_web) | Phoenix API, authentication plugs, and controllers |
| [`priv/repo/migrations`](priv/repo/migrations) | PostgreSQL and Oban schema |
| [`test`](test) | Domain, integration, and HTTP boundary tests |
| [`docs/architecture.md`](docs/architecture.md) | System design and reliability model |
| [`docs/decisions`](docs/decisions) | Architectural decision records |
| [`docs/openapi.yaml`](docs/openapi.yaml) | OpenAPI 3.1 contract |

## Why this project stands out

- **Pure state machine:** order transitions are deterministic functions with no
  database or process dependencies.
- **Idempotent writes:** clients can safely retry every command with an
  `Idempotency-Key`.
- **Serialized aggregate updates:** PostgreSQL row locks prevent concurrent
  commands from corrupting order state or event sequence numbers.
- **Transactional jobs:** Oban jobs are committed in the same transaction as
  state and audit events, eliminating the database/message dual-write gap.
- **Tenant isolation:** every query is scoped through an authenticated
  organization.
- **Immutable audit stream:** all accepted state changes create sequenced,
  correlation-aware events.
- **Operational readiness:** health probes, structured metadata, telemetry,
  rate limiting, releases, Docker, and CI are included.
- **Defense in depth:** hashed API keys, database constraints, input validation,
  static security analysis, and no dynamic atom creation from user input.

## Architecture

```text
Client
  |
  | Bearer API key + Idempotency-Key
  v
Phoenix API
  |-- tenant authentication
  |-- per-node rate limiting
  |-- request validation
  v
Orders command boundary
  |-- pure StateMachine transition
  |-- SELECT ... FOR UPDATE
  |-- update order + append event
  |-- insert Oban job
  |-- save idempotency record
  v
PostgreSQL (one atomic transaction)
  |
  v
Oban worker -> email/webhook/fulfillment adapter
```

The worker currently logs dispatches so the repository remains self-contained.
Its boundary is ready for a webhook, Kafka, email, or fulfillment adapter.

## Requirements

- Elixir 1.20+
- Erlang/OTP 28+
- PostgreSQL 17+, or Docker

The machine used to build this repository has Elixir 1.20.1 and OTP 28.4.1
installed.

## Local setup

```powershell
Copy-Item .env.example .env
mix setup
mix phx.server
```

The development seed creates:

```text
Organization: Acme Development
API key: relay_dev_sk_change_me_123456
```

Never use that credential outside local development.

With Docker:

```powershell
docker compose up --build
```

## API example

Create an order:

```powershell
$headers = @{
  Authorization = "Bearer relay_dev_sk_change_me_123456"
  "Idempotency-Key" = "order-create-1001"
}

$body = @{
  order = @{
    external_id = "checkout-1001"
    customer_email = "buyer@example.com"
    currency = "USD"
    metadata = @{ channel = "portfolio-demo" }
    items = @(
      @{
        sku = "PRO-ANNUAL"
        name = "Professional Annual Plan"
        unit_price = "149.00"
        quantity = 1
      }
    )
  }
} | ConvertTo-Json -Depth 6

Invoke-RestMethod `
  -Method Post `
  -Uri http://localhost:4000/api/v1/orders `
  -Headers $headers `
  -ContentType "application/json" `
  -Body $body
```

Transition the order:

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri http://localhost:4000/api/v1/orders/ORDER_ID/transitions `
  -Headers @{
    Authorization = "Bearer relay_dev_sk_change_me_123456"
    "Idempotency-Key" = "order-pay-1001"
  } `
  -ContentType "application/json" `
  -Body '{"command":"pay"}'
```

Endpoints:

```text
GET  /health/live
GET  /health/ready
POST /api/v1/orders
GET  /api/v1/orders/:id
POST /api/v1/orders/:id/transitions
GET  /api/v1/orders/:id/events
```

See [docs/openapi.yaml](docs/openapi.yaml) for the API contract.

## Contributing

Engineering contributions are welcome. Read
[CONTRIBUTING.md](CONTRIBUTING.md) for setup, quality gates, and pull-request
expectations. Significant design changes should include an ADR under
[`docs/decisions`](docs/decisions).

Good starting points are tracked as GitHub issues with the `good first issue`
and `help wanted` labels.

## Quality gates

```powershell
mix format --check-formatted
mix compile --warnings-as-errors
mix credo --strict
mix sobelow --config
mix test
mix dialyzer
```

The `mix precommit` alias runs the fast gates. Dialyzer is separate because its
first PLT build is intentionally expensive.

## Production configuration

Required:

```text
DATABASE_URL
SECRET_KEY_BASE
API_KEY_PEPPER
PHX_HOST
PHX_SERVER=true
```

Optional:

```text
POOL_SIZE=10
PORT=4000
REQUESTS_PER_MINUTE=120
DNS_CLUSTER_QUERY
```

Run migrations in a release with `bin/migrate`, then start with `bin/server`.

## Deliberate trade-offs

- API keys use HMAC-SHA256 because they are generated high-entropy secrets.
  Human passwords would require a slow password hash such as Argon2.
- Rate limits are per node. A global limit belongs at the gateway or in shared
  storage.
- Audit events are immutable facts but not the only source of truth. Converting
  Relay to full event sourcing would add snapshots and replay/versioning rules.
- Real notification delivery requires an adapter and destination-specific
  idempotency.

## Interview summary

> I built Relay to learn Elixir through a backend problem where its strengths
> matter. The order workflow is a pure state machine using immutable values and
> tagged tuples. Phoenix handles the API boundary, while Ecto.Multi combines the
> order update, immutable audit event, idempotency record, and Oban job in one
> PostgreSQL transaction. Row-level locking serializes concurrent commands, and
> retries are safe through idempotency keys. OTP supervises the web, telemetry,
> rate-limiter, and job-processing components. The result taught me how
> functional design and the BEAM make correctness and fault isolation explicit.

## License

Relay Orders is available under the [MIT License](LICENSE).
