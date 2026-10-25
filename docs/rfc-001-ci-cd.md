# RFC 001: CI/CD for Lambda + Terraform projects

Every Terraform project deploys the same way: **plan on each PR, apply on merge
to `main`**, through one shared workflow in this repo. Terraform owns both the
infrastructure and the Lambda code. The AWS roles CI uses are defined here, not
in the projects they deploy.

Before any project joins, its Terraform state must hold no secrets: plan jobs
read state. Lasso's state currently holds its JWKS signing key and a client
secret.

## Why

- **Two deploy models today.** Lasso deploys code through Terraform but by hand.
  Fife and aboutme upload code from CI with `update-function-code` while
  Terraform ignores it, so plans never show code changes and infra is still
  applied by hand.
- **Roles live in the repos they deploy.** Fife, train-spotting and
  bracket-clash each define their own deploy role, so a merged PR can widen
  what its own CI may do.
- **This repo must be public.** A private repo's workflows can only be called
  by other private repos. Lasso, Fife, Victoria, train-spotting and
  bracket-clash are public. The repo holds code only; state stays in S3.

## Design

| Piece | What it is |
|---|---|
| `.github/workflows/terraform.yml` | Reusable (`workflow_call`). Inputs: infra directory, build command, plan role ARN, apply role ARN. Builds, plans, comments the plan on the PR; on `main`, applies. One `concurrency` group per project. |
| `infra/projects.tf` | One map, repo → resource name prefix. The only list of managed projects. |
| `infra/modules/deploy-roles` | Per project, two roles trusted through the existing GitHub OIDC provider. |

| Role | Trusted `sub` | Permissions |
|---|---|---|
| plan | `repo:ljhurst/<repo>:pull_request` | Read-only, plus that project's state |
| apply | `repo:ljhurst/<repo>:environment:prod` | Resources under the project's prefix, plus its state |

- The plan job runs only when the PR's head branch is in the same repo, so fork
  PRs never reach the plan role.
- `stych/infra` is applied from a laptop only. It grants every other
  permission, so CI here lints and plans but never applies.
- Projects pin the workflow by tag (`@v1`). Releases follow SemVer.
- Trust policies match the standard `sub` claim. GitHub documents custom claims
  such as `job_workflow_ref` as unsupported for AWS.
- Lambda zips are built reproducibly (fixed mtimes, `zip -X`), so
  `source_code_hash` changes only when the code does.

## Rollout

| # | Work | Repo | Needs |
|---|---|---|---|
| 1 | Move Lasso's SSM secret values out of Terraform state | lasso | — |
| 2 | Import the OIDC provider; `deploy-roles` module; Lasso's roles | stych | — |
| 3 | `terraform.yml` v1 and the repo access setting | stych | — |
| 4 | Lasso joins: tfvars as committed file or vars, caller workflow, first CI apply | lasso | 1, 2, 3 |
| 5 | Porto and Victoria join | porto, victoria | 4 |
| 6 | Fife, train-spotting, bracket-clash: roles move here; Fife drops `ignore_changes`; static-site workflow for S3 + CloudFront | each | 4 |

Each row is an issue in its repo, tracked in #5. Every project's state is checked for
secrets as part of joining.

## Not doing yet

- A manual approval before apply. Merging to `main` is the approval.
- Applying the plan reviewed on the PR. Apply re-plans from `main`.
