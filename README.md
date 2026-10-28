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

### Serving it on `bylukehurst.com`

The `static-site` module puts a site behind CloudFront at
`<name>.bylukehurst.com`: the bucket is private and readable only through the
distribution, HTTP redirects to HTTPS, and a response headers policy sets the
security headers. It finds the wildcard certificate in `infra/` by domain, so
the default AWS provider must be `us-east-1`. The bucket lives in the provider's
region unless you set `region`; CloudFront is unaffected. Set `directory_index = true` for a
site built with one HTML file per page (such as Astro's default): a CloudFront
Function then serves `/dir/` and `/dir` as `/dir/index.html`.

```hcl
module "site" {
  source                  = "git::https://github.com/ljhurst/stych.git//infra/modules/static-site?ref=vX.Y.Z"
  bucket_name             = "lj-<name>"
  domain_name             = "<name>.bylukehurst.com"
  content_security_policy = "default-src 'self'"   # allow what the page loads
}

moved {   # adopt an existing bucket and policy instead of recreating them
  from = aws_s3_bucket.static_site
  to   = module.site.aws_s3_bucket.this
}
```

Pin a `vX.Y.Z` release, not `v1`: `v1` moves. After the apply, add a DNS-only
`CNAME <name>` in Cloudflare pointing at the `cname_target` output, and pass
the `distribution_id` output to the `site` job so each deploy invalidates the
cache.

## Fronting a Lambda Function URL

A Function URL has no custom domain of its own. The `function-url-site` module
puts CloudFront in front of one at `<name>.bylukehurst.com`: HTTP redirects to
HTTPS, nothing is cached, every method and header (including `Authorization`)
reaches the function, and the managed security headers policy is attached. It
finds the wildcard certificate by domain, so the default AWS provider must be
`us-east-1`.

```hcl
module "front" {
  source         = "git::https://github.com/ljhurst/stych.git//infra/modules/function-url-site?ref=vX.Y.Z"
  domain_name    = "<name>.bylukehurst.com"
  function_url   = aws_lambda_function_url.<name>.function_url
  origin_timeout = 120   # at least the function's own timeout
}
```

The project's CI roles need the CloudFront and certificate permissions: add a
`cloudfront-access` module in `infra/project_<name>.tf` and list its
`read_policy_json` and `write_policy_json` as `source_policy_documents` of the
project's read and write policies (see `project_victoria.tf`).

The origin also gets an `X-Forwarded-Host` header with the public hostname, replacing
any value the viewer sent, for services that build their own URLs from it (Lasso's
OIDC provider does).

### Locking a Function URL

A Function URL is public. Origin access control would lock it to CloudFront, but
it replaces the viewer's `Authorization` header with its own signature, which
breaks Bearer tokens and Basic client auth, and it needs every client to hash
`POST` bodies. Instead the site shares a secret with its origin:

1. Pass `origin_verify_kvs_arn = <output origin_verify_kvs_arn>` to the module and
   to the project's `cloudfront-access` module. A viewer-request CloudFront
   Function then sets `X-Origin-Verify` from the shared key value store, keyed by
   the site's hostname, and `X-Viewer-Ip` from the connection (both replace any
   value the viewer sent).
2. Run `scripts/set-origin-verify.sh <hostname> <ssm-parameter>` with admin
   credentials. It writes a fresh random secret to the key value store and to the
   SSM parameter without printing it or putting it in Terraform state. Run it
   again to rotate.
3. The service compares `X-Origin-Verify` with its SSM parameter and answers 403
   on a mismatch; when it matches, `X-Viewer-Ip` is the real client address.

A host without a secret sends none, so the service refuses the request and the
edge never fails. Do step 2 before the service starts enforcing.

`origin_timeout` can't exceed the account's `Response timeout per origin`
quota (120 seconds). The Function URL stays reachable directly: origin access
control would make every client hash its POST bodies, which MCP clients do
not, so the service must authenticate requests itself. After the apply, add a
DNS-only `CNAME <name>` in Cloudflare pointing at the `cname_target` output.

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

The workflow caches the pre-commit environments and the tflint plugin, keyed on
`.pre-commit-config.yaml` and `.tflint.hcl`, so `tflint --init` rarely calls
GitHub's rate-limited API.

## Testing a project

`test.yml` runs one suite per call, so a repo with two suites calls it twice.
Each call is a required-check candidate named `<job> / test`.

```yaml
jobs:
  backend:
    uses: ljhurst/stych/.github/workflows/test.yml@v1
    with:
      command: go test ./...
      working-directory: backend
      go-version-file: backend/go.mod
      paths: |
        backend/**
        .github/workflows/check.yml

  frontend:
    uses: ljhurst/stych/.github/workflows/test.yml@v1
    with:
      command: npm run test
      setup-command: npm ci
      working-directory: frontend
      node-version-file: frontend/.nvmrc
      paths: |
        frontend/**
        .github/workflows/check.yml
```

`paths` is a list of git pathspecs from the repo root. A pull request that
touches none of them skips the suite's steps but the job still reports success,
so a required check never hangs. Pushes always run every suite. A trigger-level
`on.paths` filter in the caller would leave the required check pending forever,
so don't use one.

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

The wildcard certificate needs two applies the first time, because the apply
waits for DNS validation and prints nothing meanwhile:

1. `terraform -chdir=infra apply -target=aws_acm_certificate.wildcard`
2. Add the records from `terraform -chdir=infra output
   certificate_validation_records` in Cloudflare as DNS only.
3. Run the full apply.

Keep those records. ACM renews the certificate through them, and deleting one
breaks every site in about 13 months.

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
pull request approval and deleting merged branches have no Terraform
resource, so a script sets each. Apply all of it from a laptop:

```bash
export AWS_PROFILE=luke-hurst-admin GITHUB_TOKEN=$(gh auth token)
terraform -chdir=github init
terraform -chdir=github plan -out=github.tfplan
terraform -chdir=github apply github.tfplan
scripts/apply-fork-approval.sh
scripts/apply-branch-cleanup.sh
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

A Lambda project's function, log group and parameter rules come from the
`lambda-access` module (see `project_dio.tf`), its DynamoDB tables from the
`dynamodb-access` module and its `<name>-*` resource groups from the
`resource-group-access` module (see `project_lasso.tf`); the project file adds
only what is specific to it. A static site serves from
`<name>.bylukehurst.com`, so its policies come from the `static-site-access`
module (see `project_bracket_clash.tf`) instead of being written out: it grants the S3 and CloudFront access a site needs, with
CloudFront changes limited to resources tagged `Project=<name>`.
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
