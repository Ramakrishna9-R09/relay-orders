# Security Policy

## Supported versions

Security fixes are applied to the latest version on the `main` branch.

## Reporting a vulnerability

Do not open a public issue for suspected vulnerabilities.

Use GitHub's private vulnerability reporting feature for this repository. Include:

- affected endpoint or component;
- reproduction steps or proof of concept;
- expected impact;
- suggested mitigation, if available.

Please allow reasonable time for investigation and remediation before public
disclosure.

## Security model

- API credentials are stored as peppered HMAC hashes.
- Tenant identity is resolved before business queries execute.
- Every business query includes an organization boundary.
- Mutations require idempotency keys.
- Known commands are mapped from an allowlist; user input never creates atoms.
- Ecto parameterization and database constraints provide defense in depth.
- Oban persists side effects in the same transaction as business state.

Production deployments must replace all development secrets, terminate TLS,
restrict database access, rotate credentials, and centralize rate limiting.

Dependency updates are proposed automatically through Dependabot. Security
updates should be reviewed and merged promptly after CI passes.
