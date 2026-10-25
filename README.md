# stych

**S**hared **T**erraform & **Y**AML **C**I **H**ub — the deploy plumbing that
stitches every project together. Every release crosses the Styx on its way to
production.

- `.github/workflows/` — reusable workflows that projects call to plan and apply.
- `infra/` — the GitHub OIDC provider and each project's plan/apply roles.
- `docs/` — design decisions, starting with [RFC 001: CI/CD](docs/rfc-001-ci-cd.md).
