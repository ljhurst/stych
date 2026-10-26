# Security guidance

The rules every project on stych follows. The README covers how; this
covers what and why. When a change would break one of these, change the
guidance here first.

## Credentials

- **No long-lived keys.** People sign in through IAM Identity Center
  (`aws sso login`). CI assumes roles through GitHub OIDC. Neither stores an
  access key, and the account has no IAM users.
- **The root user has no access keys and has MFA on.** Check it with:
  ```bash
  aws iam get-account-summary --profile luke-hurst-admin \
    --query 'SummaryMap.{RootAccessKeys:AccountAccessKeysPresent,RootMFA:AccountMFAEnabled,Users:Users}'
  ```
  The result should be `RootAccessKeys: 0`, `RootMFA: 1` and `Users: 0`.
- **`luke-hurst-admin` is emergency access,** and the only way to apply
  `stych/infra` and `stych/github`. It stays outside stych, so no stych
  apply can lock it out.

## Access

- **Least privilege per project.** Each project's access lists its own
  resources by ARN. It never uses AWS-managed `*FullAccess` policies.
- **Deploying and operating are separate.**
  - *Deploy* (read + write) is shared by the project's permission set and its
    CI apply role, so people and CI can't drift apart.
  - *Operate* (data, secrets, logs) is for people only.
  - CI never reads secrets or user data.
- **Plans are read-only.** PR plans run as a role that can't change anything.
  Applies run only in the `prod` environment, which only `main` can deploy to.
- **Projects can't widen their own access.**
  - CI roles live under `/stych/`, outside every project's role pattern.
  - Every role a project creates must carry the project's permissions
    boundary, and the boundary can't be removed.
- **Site buckets are private.** A static site is served through CloudFront
  with origin access control, never from a public S3 endpoint.
- **A project changes only its own distributions.** Updating, deleting and
  invalidating CloudFront distributions requires the project's `Project` tag.
  Origin access controls and response headers policies can't be tagged, so a
  project's role can change those in the account.
- **Read policies cover everything Terraform's refresh reads.** A missing
  read makes a plan show a live resource as deleted. For S3 that includes
  `s3:ListBucket`.
- **Verify, don't assume.** Run `scripts/verify-access.sh` after every
  `infra/` apply. Before applying a new policy, simulate it with
  `aws iam simulate-custom-policy`.

## Secrets

- Secrets live in SSM and are written outside Terraform.
- Terraform refers to them by name or ARN, never by value. Anything
  Terraform manages lands in state, including decrypted values.
- Never put a secret in a Lambda environment variable, tfvars, or a
  workflow file. Plan comments and site previews on public repos are public.
- If a secret reaches state, move it out with
  `removed { lifecycle { destroy = false } }`, then purge the old state
  versions.

## Changing infrastructure

- **Plan, read the plan, apply the saved plan.** Never apply something
  different from what was reviewed.
- **PR plans skip the state lock.** They are read-only, so they never block
  each other or an apply. The apply plans again under the lock before it
  changes anything.
- **Keep the certificate's validation records in DNS.** ACM renews through
  them, and removing one lets the wildcard certificate expire.
- **Every destroy and replace must be expected.** The shared workflow puts a
  warning at the top of the PR comment when a plan contains one.
- **Bring existing resources in with `import`, not by recreating them.**
  Remove the `import` blocks once applied.
- **Before anything irreversible,** such as purging state or deleting
  history, back up first, then confirm the backup's contents are safe to
  delete afterwards.

## GitHub and public repos

- **Forks can't reach AWS.**
  - Fork PRs get a read-only token and no OIDC token, so they can't assume a
    role.
  - No workflow uses `pull_request_target`.
  - Plan and preview jobs skip forks.
  - Workflows from every external contributor need approval before they run.
- **Repo settings are code** (`stych/github`):
  - `main` needs a PR and the required checks, and can't be force-pushed or
    deleted;
  - workflow tokens are read-only and can't approve PRs;
  - merged pull request branches are deleted;
  - Dependabot alerts and security updates are on, and each repo's
    `dependabot.yml` groups updates into one PR per ecosystem, monthly, with a
    cooldown, while security updates stay immediate. Major versions of
    language dependencies are upgraded by hand, not batched;
  - release tags are immutable.
- **Workflows:**
  - grant `id-token` and `pull-requests` only on the jobs that need them;
  - pass inputs to shell steps through `env`, never inline `${{ }}`;
  - pin third-party actions by commit SHA;
  - stych's own actions use `@v1`.

## Code quality as a guardrail

- Every language in a repo has its standard formatter and linter as
  pre-commit hooks.
- CI runs the same hooks, and merging requires them to pass.
- Every repo runs gitleaks (secrets) and zizmor (workflow security).
- Never skip hooks with `--no-verify`. Never disable a rule without a comment
  saying why.
