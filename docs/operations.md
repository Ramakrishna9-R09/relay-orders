# Operations Runbook

This runbook covers the minimum operational procedures for a production Relay
Orders deployment.

## Deployment sequence

1. Build an immutable release from a tagged commit.
2. Provide `DATABASE_URL`, `SECRET_KEY_BASE`, `API_KEY_PEPPER`, and `PHX_HOST`.
3. Run `bin/migrate` once for the release.
4. Start application instances with `bin/server`.
5. Wait for `/health/ready` before adding instances to load-balancer traffic.
6. Verify command latency, database pool saturation, and Oban queue depth.

Database migrations must be backward compatible while old and new application
versions may overlap.

## Health signals

`GET /health/live` confirms that the HTTP process is alive.

`GET /health/ready` confirms that the application can query PostgreSQL.

Neither endpoint proves that asynchronous integrations are healthy. Monitor
Oban queue latency, retries, and discarded jobs separately.

## Useful database checks

Recent discarded jobs:

```sql
SELECT id, worker, args, errors, discarded_at
FROM oban_jobs
WHERE state = 'discarded'
ORDER BY discarded_at DESC
LIMIT 50;
```

Queue age:

```sql
SELECT queue, MIN(scheduled_at) AS oldest_available
FROM oban_jobs
WHERE state IN ('available', 'retryable')
GROUP BY queue;
```

Order event consistency:

```sql
SELECT o.id, o.version, COUNT(e.id) AS event_count
FROM orders o
LEFT JOIN order_events e ON e.order_id = o.id
GROUP BY o.id, o.version
HAVING o.version <> COUNT(e.id);
```

The final query should return no rows.

## Incident: elevated command errors

1. Group errors by code and route.
2. Check database connectivity and pool queue time.
3. Inspect PostgreSQL locks and slow queries.
4. Check whether one tenant is producing unusual traffic.
5. Avoid retrying non-idempotent administrative operations manually.
6. For API commands, preserve the original idempotency key when retrying.

## Incident: growing Oban backlog

1. Compare available-job age with normal processing latency.
2. Inspect the most common worker errors.
3. Confirm external dependencies are reachable.
4. Increase worker concurrency only after checking database and downstream
   capacity.
5. Pause the affected queue if retries are amplifying a downstream outage.
6. Resume gradually and watch error rate and queue age.

## API key rotation

Relay currently stores one API key hash per organization. Until multi-key
rotation is implemented:

1. Schedule a coordinated rotation window.
2. Generate a high-entropy key.
3. Hash it with the active production pepper.
4. Replace the stored hash transactionally.
5. Update the client secret store.
6. Verify authentication and revoke the old credential.

Never log plaintext API keys.

## Backup and recovery

- Use encrypted PostgreSQL backups with point-in-time recovery.
- Test restoration regularly in an isolated environment.
- Back up business tables and Oban tables together so committed state and
  pending side effects remain consistent.
- After restoration, verify order versions, event counts, and queue age before
  reopening traffic.

## Rollback

Prefer rolling forward with a corrective release. If rollback is required:

1. Confirm the previous application version supports the current schema.
2. Remove the faulty release from traffic.
3. Start the previous immutable release.
4. Do not reverse migrations that may contain new production data without a
   reviewed recovery plan.
