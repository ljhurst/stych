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
- `docs/` — design decisions ([RFC 001: CI/CD](docs/rfc-001-ci-cd.md)) and [security guidance](docs/security.md).

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
  contents: read

jobs:
  terraform:
    permissions:
      id-token: write       # assume the plan or apply role
      contents: read
      pull-requests: write  # post the plan comment
    uses: ljhurst/stych/.github/workflows/terraform.yml@v1
    with:
      plan-role-arn: arn:aws:iam::755958650241:role/stych/<name>-ci-plan
      apply-role-arn: arn:aws:iam::755958650241:role/stych/<name>-ci-apply
      build-command: scripts/build_lambda.sh   # optional, run from the repo root
      node-version-file: .node-version         # optional
      go-version-file: go.mod                  # optional
      setup-uv: true                           # optional, for uv-built Python
```

Grant `id-token` and `pull-requests` only on the jobs that call the shared
workflows; zizmor flags them at the workflow level. The project also needs:

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
    permissions:
      id-token: write
      contents: read
      pull-requests: write
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
scripts/verify-access.sh
```

`scripts/verify-access.sh` runs every project's three principals through the
standard allow/deny matrix:

- own state allowed; other projects' state and secrets denied
- roles only within the boundary
- no editing its own CI roles
- the plan role can't write

Pass a project name to check just that one, and an extra checks file to add project-specific checks (see the script header).

The state bucket and the OIDC provider have `prevent_destroy`: every
project's state and CI depend on them.

## Repository settings

`github/` manages each repo's GitHub settings with the `integrations/github`
provider. Every repo in `github/repos.tf` gets:

- a `main` ruleset: no deletion, no force-push, changes through a PR, and the
  required checks (not on private repos, which the free plan excludes). Repos
  with no CI/CD set `require_pull_request = false`, which drops the PR rule
  and keeps force-push and deletion blocked
- a `prod` environment that only `main` may use, for repos that deploy
- read-only workflow tokens that can't approve pull requests
- Dependabot vulnerability alerts and security updates

Each repo also carries its own `.github/dependabot.yml`: version updates run
monthly, one grouped PR per ecosystem, with a 7-day cooldown. Security
updates ignore the schedule and cooldown and arrive as one grouped PR. Copy
`.github/dependabot.yml` from this repo and keep the ecosystems the repo uses.
The monthly batch holds minor and patch updates only. For npm, Go and uv, major
versions are ignored and upgraded by hand.

stych's release tags (`v*.*.*`) are protected by their own ruleset. Fork
pull request approval has no Terraform resource, so a script sets it. Apply
both from a laptop:

```bash
export AWS_PROFILE=luke-hurst-admin GITHUB_TOKEN=$(gh auth token)
terraform -chdir=github init
terraform -chdir=github plan -out=github.tfplan
terraform -chdir=github apply github.tfplan
scripts/apply-fork-approval.sh
```

## Adding a project

Use the `stych-onboard` skill, which walks through every step. Install it
once with `ln -s ~/learning/stych/.claude/skills/stych-onboard
~/.claude/skills/stych-onboard`.

`infra/project_<name>.tf` holds only what is specific to the project: its
ARNs and its boundary, read, write and operate statements. The module adds
everything every project gets:

- state read, write and lock on `<name>/terraform.tfstate`
- reading `<name>-*` roles
- creating or changing them only with the boundary attached
- never removing the boundary

## Releasing

Callers pin `@v1`, and the workflows reference
`setup-toolchains@v1`, so a release is:

1. merge the PR
2. tag the merge commit `vX.Y.Z` (SemVer: a new input or workflow is minor)
3. move `v1` to it: `git tag -f v1 vX.Y.Z^{} && git push -f origin v1`
4. re-run Check on `main`

A PR that changes `setup-toolchains` fails its own Check until `v1` moves,
because its workflows still resolve the action at the old `v1`.

## Security model

The full guidance is in [docs/security.md](docs/security.md). In short:

Fork pull requests can't touch AWS:

- They run with a read-only `GITHUB_TOKEN`, and requesting an OIDC token needs
  `id-token: write`, so they can't assume any role.
- The plan and preview jobs skip fork PRs as well.
- No workflow uses `pull_request_target`.

Applying needs a push to `main`, where only the owner can write, and each
project's `prod` environment admits only `main`.

Plan comments and site previews on public repos are public, so never put a
secret in a Lambda environment variable, tfvars, or Terraform state. Secrets
live in SSM and are written outside Terraform.
