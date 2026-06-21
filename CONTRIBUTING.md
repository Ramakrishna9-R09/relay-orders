# Contributing to Relay Orders

Thanks for considering a contribution. Relay Orders aims to be a compact,
high-quality reference for reliable Elixir backend design.

## Development workflow

1. Fork the repository and create a focused branch.
2. Install Elixir 1.20+, Erlang/OTP 28+, and PostgreSQL 17+.
3. Run `mix setup`.
4. Make the smallest coherent change.
5. Add or update tests.
6. Run `mix precommit`.
7. Open a pull request using the repository template.

## Engineering standards

- Keep business rules pure where possible.
- Return tagged tuples for expected failure modes.
- Scope all persisted business data by organization.
- Make write endpoints safe to retry.
- Couple durable side effects to database transactions through Oban.
- Never create atoms from untrusted input.
- Add database constraints for invariants that must survive application bugs.
- Document consequential design changes with an ADR.

## Commit messages

Use an imperative, scoped subject:

```text
orders: prevent duplicate fulfillment dispatch
api: return correlation id in error responses
docs: explain idempotency conflict semantics
```

## Pull requests

A good pull request explains:

- the problem and why it matters;
- the chosen solution and alternatives considered;
- how correctness was verified;
- operational, migration, or compatibility risks.

Security vulnerabilities must follow [SECURITY.md](SECURITY.md), not public
issues.
