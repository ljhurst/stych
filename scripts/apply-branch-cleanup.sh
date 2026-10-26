#!/usr/bin/env bash
# Deletes a pull request's branch once it merges, on every repo in
# github/repos.tf. The module doesn't manage the repository resource itself,
# so the setting lives here instead.
#
# Usage: scripts/apply-branch-cleanup.sh   (after `terraform -chdir=github apply`)
set -euo pipefail

cd "$(dirname "$0")/.."

for repo in $(terraform -chdir=github output -json repos | jq -r '.[]'); do
  endpoint="repos/ljhurst/${repo}"
  current=$(gh api "$endpoint" --jq .delete_branch_on_merge)
  if [ "$current" = "true" ]; then
    echo "${repo}: true"
  else
    gh api -X PATCH "$endpoint" -F delete_branch_on_merge=true >/dev/null
    echo "${repo}: ${current} -> true"
  fi
done
