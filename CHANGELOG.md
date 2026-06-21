# Changelog

All notable changes to Relay Orders are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Planned

- Signed outbound webhooks with delivery history
- Organization-scoped API key rotation
- OpenTelemetry exporter and dashboards
- Property-based state machine tests

## [1.0.0] - 2026-06-21

### Added

- Multi-tenant Phoenix JSON API
- Pure functional order state machine
- PostgreSQL-backed orders, line items, and immutable audit events
- Idempotent create and transition commands
- Row-level locking for concurrent aggregate updates
- Transactional Oban jobs
- Hashed API key authentication and per-node rate limiting
- Health probes, telemetry, Docker release, OpenAPI contract, and CI
- Domain, integration, and HTTP boundary test suites
