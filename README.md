# stych

**S**hared **T**erraform & **Y**AML **C**I **H**ub — the deploy plumbing that
stitches every project together. Every release crosses the Styx on its way to
production.

- `.github/workflows/` — reusable workflows that projects call to plan and apply.
- `infra/` — the state bucket, the GitHub OIDC provider, and each project's access.
- `docs/` — design decisions, starting with [RFC 001: CI/CD](docs/rfc-001-ci-cd.md).

## Applying `infra/`

`infra/` grants every other project its permissions, so it is applied from a
laptop with the `luke-hurst-admin` profile only, never from CI:

```bash
aws sso login --profile luke-hurst-admin
export AWS_PROFILE=luke-hurst-admin
terraform -chdir=infra init
terraform -chdir=infra plan -out=stych.tfplan
terraform -chdir=infra apply stych.tfplan
```

The state bucket and the OIDC provider have `prevent_destroy`: every
project's state and CI depend on them.
