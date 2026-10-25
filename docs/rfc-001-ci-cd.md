# RFC 001: CI/CD for Lambda + Terraform projects

Every Terraform project deploys the same way: **plan on each PR, apply on merge
to `main`**, through one shared workflow in this repo. Terraform owns both the
infrastructure and the Lambda code. Everything that decides who may deploy a
project lives here, not in the project: the state bucket, the GitHub OIDC
provider, and each project's SSO permission set and CI roles.

Before any project joins, its Terraform state must hold no secrets: plan jobs
read state.

## Why

- **Two deploy models today.** Lasso deploys code through Terraform but by hand.
  Fife and aboutme upload code from CI with `update-function-code` while
  Terraform ignores it, so plans never show code changes and infra is still
  applied by hand.
- **Roles live in the repos they deploy.** Fife, train-spotting and
  bracket-clash each define their own deploy role, so a merged PR can widen
  what its own CI may do.
- **Shared pieces have no owner.** The state bucket was made by hand, and the
  GitHub OIDC provider that four projects use belongs to aboutme's Terraform.
  SSO permission sets were made with hand-run `aws sso-admin` commands, and
  `lasso-deploy` can read other projects' state.
- **This repo must be public.** A private repo's workflows can only be called
  by other private repos. Lasso, Fife, Victoria, train-spotting and
  bracket-clash are public. The repo holds code only; state stays in S3.

## Design

| Piece | What it is |
|---|---|
| `.github/workflows/terraform.yml` | Reusable (`workflow_call`). Inputs: infra directory, build command, plan role ARN, apply role ARN. Builds, plans, comments the plan on the PR; on `main`, applies. One `concurrency` group per project. |
| `infra/` foundation | The state bucket `lj-tf-state` (versioning, encryption, old-version expiry, TLS-only policy) and the GitHub OIDC provider. Both imported, both `prevent_destroy`. |
| `infra/project_<name>.tf` | One file per managed project: its policy documents, written as ARN patterns per service, and its `project-access` module call. |
| `infra/modules/project-access` | Per project: four policies, the `<name>-deploy` SSO permission set, and two CI roles under `/stych/`. |

| Policy | Grants | Used by |
|---|---|---|
| `<name>-boundary` | The most any of the project's workload roles may do | Permissions boundary on those roles |
| `<name>-deploy-read` | Read the project's resources and its state; take the state lock | Plan role, apply role, permission set |
| `<name>-deploy-write` | Create, change and delete the project's resources; write state; manage `<name>-*` roles only with the boundary attached | Apply role, permission set |
| `<name>-operate` | Local-only access: table data, secrets, logs | Permission set |

| Role | Trusted `sub` | Policies |
|---|---|---|
| `<name>-ci-plan` | `repo:ljhurst/<repo>:pull_request` | read |
| `<name>-ci-apply` | `repo:ljhurst/<repo>:environment:prod` | read + write |

- The deploy policies (read + write) are the same for you and for CI, so the
  two can't drift. Only people get operate, so CI never reads data or secrets.
- A workload role can only be created or changed with the project's boundary
  attached, and the boundary can't be removed. Deploy access can't reach
  admin by editing the role its Lambda runs as.
- CI roles live under `/stych/`, outside every project's `<name>-*` role
  pattern, so a project can't edit its own CI roles.

- The plan job runs only when the PR's head branch is in the same repo, so fork
  PRs never reach the plan role.
- `stych/infra` is applied from a laptop with `luke-hurst-admin` only. It
  grants every other permission, so CI here lints and plans but never applies.
- The `luke-hurst-admin` permission set stays outside stych as emergency
  access, so no stych apply can lock its own operator out.
- Projects pin the workflow by tag (`@v1`). Releases follow SemVer.
- Trust policies match the standard `sub` claim. GitHub documents custom claims
  such as `job_workflow_ref` as unsupported for AWS.
- Lambda zips are built reproducibly (fixed mtimes, `zip -X`), so
  `source_code_hash` changes only when the code does.

## Rollout

| # | Work | Repo | Needs |
|---|---|---|---|
| 1 | Move SSM secret values out of Terraform state (done) | lasso, porto, victoria | — |
| 2 | Hand the GitHub OIDC provider over to stych (done) | aboutme | — |
| 3 | Foundation: import the state bucket and OIDC provider (done) | stych | 2 |
| 4 | `project-access` module, Lasso end to end: boundary on its Lambda role, FullAccess policies off `lasso-deploy` | stych, lasso | 3 |
| 5 | `terraform.yml` v1 and the repo access setting | stych | — |
| 6 | Lasso joins: tfvars as committed file or vars, caller workflow, first CI apply | lasso | 1, 4, 5 |
| 7 | Porto and Victoria join | porto, victoria | 6 |
| 8 | Fife, train-spotting, bracket-clash: roles move here; Fife drops `ignore_changes`; static-site workflow for S3 + CloudFront | each | 6 |
| 9 | aboutme and dio join | aboutme, dio | 6 |

Each row is an issue in its repo, tracked in #5. Every project's state is
checked for secrets as part of joining.

## Not doing yet

- A manual approval before apply. Merging to `main` is the approval.
- Applying the plan reviewed on the PR. Apply re-plans from `main`.
