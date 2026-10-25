#!/usr/bin/env bash
# Requires approval for fork pull request workflows from every external
# contributor on each public repo in github/repos.tf. GitHub's Terraform
# provider can't manage this setting, so it lives here instead.
#
# Usage: scripts/apply-fork-approval.sh   (after `terraform -chdir=github apply`)
set -euo pipefail

cd "$(dirname "$0")/.."

want=all_external_contributors

for repo in $(terraform -chdir=github output -json public_repos | jq -r '.[]'); do
  endpoint="repos/ljhurst/${repo}/actions/permissions/fork-pr-contributor-approval"
  current=$(gh api "$endpoint" --jq .approval_policy)
  if [ "$current" = "$want" ]; then
    echo "${repo}: ${want}"
  else
    gh api -X PUT "$endpoint" -f approval_policy="$want" > /dev/null
    echo "${repo}: ${current} -> ${want}"
  fi
done
