# stych

**S**hared **T**erraform & **Y**AML **C**I **H**ub — the deploy plumbing that
stitches every project together. Every release crosses the Styx on its way to
production.

```text
   the living                       the Styx                       the underworld
  (laptops, PRs)                                                  (production AWS)

                     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   lasso            ~~~~~~~                o   /          ~~~~~~~       Lambda
   porto   ---->   ~~~~~~~                /|\_/            ~~~~~~~ ---> DynamoDB
   fife             ~~~~~~~      _________/_\_________    ~~~~~~~       S3
   ...               ~~~~~~~~~~~~\_______stych_______/~~~~~~~~~~        CloudFront
                     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

          every crossing is paid with an obol: one short-lived OIDC token
```

- `.github/workflows/` — reusable workflows that projects call to plan and apply.
- `infra/` — the state bucket, the GitHub OIDC provider, and each project's access.
- `docs/` — design decisions, starting with [RFC 001: CI/CD](docs/rfc-001-ci-cd.md).

## Deploying a project

A project calls the shared workflow, which plans on every PR (posting the plan
as a comment) and applies on merge to the default branch:

```yaml
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read
  pull-requests: write

jobs:
  terraform:
    uses: ljhurst/stych/.github/workflows/terraform.yml@v1
    with:
      plan-role-arn: arn:aws:iam::755958650241:role/stych/<name>-ci-plan
      apply-role-arn: arn:aws:iam::755958650241:role/stych/<name>-ci-apply
      build-command: scripts/build_lambda.sh   # optional, run from the repo root
      node-version-file: .node-version         # optional
      go-version-file: go.mod                  # optional
      setup-uv: true                           # optional, for uv-built Python
```

The project also needs:

- its roles in `infra/project_<name>.tf`, applied (see below)
- a `prod` environment whose deployment branches are limited to `main`: the
  apply role trusts `environment:prod`, so this is what keeps other branches
  from applying

A project's read policy must allow every read Terraform's refresh makes. If a
read is denied, the plan shows that resource as deleted and plans to recreate
it. For an S3 bucket this includes `s3:ListBucket`, because Terraform checks
the bucket exists with HeadBucket. Any plan that destroys or replaces
resources lists them in a warning at the top of the PR comment.

## Deploying a static site

S3-hosted frontends add a `site` job next to `terraform`. A PR previews the
sync, listing uploads and deletes. Merging deploys the same build artifact
the PR previewed:

```yaml
  site:
    needs: terraform
    uses: ljhurst/stych/.github/workflows/static-site.yml@v1
    with:
      plan-role-arn: arn:aws:iam::755958650241:role/stych/<name>-ci-plan
      apply-role-arn: arn:aws:iam::755958650241:role/stych/<name>-ci-apply
      bucket: lj-<name>
      site-dir: site              # synced to the bucket root with --delete
      build-command: ...          # optional; must leave the site in site-dir
      node-version-file: .nvmrc   # optional
      distribution-id: ...        # optional CloudFront invalidation
```

## Checking a project

Every repo's `check.yml` runs its own pre-commit hooks:

```yaml
on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  pre-commit:
    uses: ljhurst/stych/.github/workflows/pre-commit.yml@v1
    with:
      terraform-version: "1.17.0"    # only when the hooks include terraform ones
      setup-command: npm ci          # optional, e.g. for hooks that call npm scripts
```

Lock Terraform providers for both platforms (`terraform providers lock
-platform=darwin_arm64 -platform=linux_amd64`). Otherwise the validate hook
rewrites the lock file in CI and the check fails.

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
