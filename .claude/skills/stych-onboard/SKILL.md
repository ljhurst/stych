---
name: stych-onboard
description: Bring a repo onto stych, the shared CI/CD and security home, or set up a new repo the same way. Covers AWS access (permission set, CI plan/apply roles, boundary), GitHub settings (ruleset, prod environment, read-only tokens, Dependabot, fork approval), the deploy and check workflows, secrets, and formatters/linters. Use when the user says "onboard X to stych", "move X's deploys to stych", "secure this repo", "set up CI for X", or creates a new repo. Supersedes the older aws-deploy-migration skill.
user-invocable: true
---

# Onboard a repo to stych

stych (`~/learning/stych`) holds everything that decides who may deploy a
project and how its code is checked. Its README is the reference for each
step; this skill is the order to do them in and the gates between them.

Plan first (the user's CLAUDE.md requires it), then work through the steps.
Steps 1–3 change stych; 4–7 change the project repo.

## 1. Secrets out of Terraform state
Plans read state, and plan comments on public repos are public.

- Find every `aws_ssm_parameter`, secret version or generated secret the
  project's Terraform manages.
- Move each one out, as Lasso, Porto and Victoria did:
  - drop the resource with `removed { lifecycle { destroy = false } }`;
  - refer to the parameter by name and ARN instead;
  - write its value outside Terraform.
- Then purge the old state versions (ask first: this can't be undone).
- Never put secrets in Lambda environment variables or tfvars.

## 2. AWS access in stych
1. Add `infra/project_<name>.tf` per README "Adding a project". It holds only
   the project's own ARNs and its boundary, read, write and operate
   statements; the module adds state, role and boundary rules.
2. Read policies must cover every read Terraform's refresh makes. For S3
   that includes `s3:ListBucket`; without it the plan reports the bucket as
   deleted.
3. If the project has a `<name>-deploy` permission set, add an `import`
   block for it and its assignment, then remove the import after applying.
4. Get the repo's OIDC subject prefix from
   `gh api repos/ljhurst/<repo>/actions/oidc/customization/sub`. Newer repos
   use immutable IDs.
5. Plan. Before the user applies, simulate the new read policy with
   `aws iam simulate-custom-policy`. The user applies with `luke-hurst-admin`;
   auto mode blocks this apply.
6. Run `scripts/verify-access.sh <name>`. It must be all green.

## 3. GitHub settings in stych
1. Add the repo to `github/repos.tf`. If it already has a `main` ruleset or a
   `prod` environment, add temporary `import` blocks for them, then remove
   the blocks once applied.
2. Plan; the user applies (README "Repository settings").
3. Run `scripts/apply-fork-approval.sh`.

## 4. Workflows in the project
- `.github/workflows/deploy.yml` calls `terraform.yml@v1`, plus
  `static-site.yml@v1` for S3 sites (README "Deploying a project" and
  "Deploying a static site"). Grant `id-token` and `pull-requests` on those
  calling jobs only.
- `.github/workflows/check.yml` calls `pre-commit.yml@v1` (README
  "Checking a project").
- Commit the non-secret `infra/terraform.tfvars`.
- Lock providers for `darwin_arm64` and `linux_amd64`.
- Remove any deploy roles and repo variables the project defined itself.
  The first CI apply destroys the roles; the destroy warning lists them.

## 5. Formatters and linters
Apply the language rule in the user's CLAUDE.md: every language in the
repo gets its standard formatter and linter as pre-commit hooks, and
`pre-commit run --all-files` passes. Lint fixes go in separate,
formatting-only commits.

## 6. Prove it on a PR
The PR's runs must show:
- Check green;
- the plan ran as `<name>-ci-plan`;
- the plan says `No changes`, or destroys only what step 4 removed;
- for sites, the preview shows 0 deletes.

## 7. Cut over
1. Detach the permission set's old FullAccess or AWS-managed policies.
   Save the list first.
2. Re-run `verify-access.sh` and a local plan with the scoped set.
3. The user merges. The first CI apply runs as `<name>-ci-apply`.
4. Smoke-test the app.
5. Tick stych#5 and update RFC 001's rollout table.
