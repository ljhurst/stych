#!/usr/bin/env bash
# Checks a project's three principals (its SSO permission set and both CI
# roles) against the access every stych project must have and must not have,
# using the IAM policy simulator. Run it after every `infra/` apply.
#
# Usage: scripts/verify-access.sh [<project> [extra-checks-file]]
#   With no project, checks every project in infra/project_*.tf.
#   extra-checks-file: lines of "<sso|plan|apply> <allow|deny> <action> <resource-arn>"
#
# Needs credentials that can call iam:SimulatePrincipalPolicy, e.g. the
# luke-hurst-admin profile.
set -euo pipefail

cd "$(dirname "$0")/.."

projects=$(sed -n 's/^ *name *= *"\([a-z0-9-]*\)"$/\1/p' infra/project_*.tf)

if [ $# -eq 0 ]; then
  status=0
  for p in $projects; do
    "$0" "$p" || status=1
  done
  exit "$status"
fi

project=$1
extra="${2:-}"

account=$(aws sts get-caller-identity --query Account --output text)
region=$(aws configure get region || echo us-east-1)
iam="arn:aws:iam::${account}"
state="arn:aws:s3:::lj-tf-state"

sso=$(aws iam list-roles --path-prefix /aws-reserved/sso.amazonaws.com/ \
  --query "Roles[?starts_with(RoleName, 'AWSReservedSSO_${project}-deploy_')].Arn" --output text)
plan="${iam}:role/stych/${project}-ci-plan"
apply="${iam}:role/stych/${project}-ci-apply"
boundary="${iam}:policy/stych/${project}-boundary"

if [ -z "$sso" ]; then
  echo "no SSO role found for ${project}-deploy" >&2
  exit 1
fi

others=$(grep -vx "$project" <<<"$projects")

total=0
failed=0

check() {
  local who=$1 want=$2 action=$3 resource=$4
  shift 4
  local arn decision got
  case "$who" in
  sso) arn=$sso ;;
  plan) arn=$plan ;;
  apply) arn=$apply ;;
  esac
  decision=$(aws iam simulate-principal-policy --policy-source-arn "$arn" \
    --action-names "$action" --resource-arns "$resource" "$@" \
    --query 'EvaluationResults[0].EvalDecision' --output text)
  case "$decision" in
  allowed) got=allow ;;
  *) got=deny ;;
  esac
  total=$((total + 1))
  if [ "$got" != "$want" ]; then
    failed=$((failed + 1))
    echo "FAIL ${who} ${action} on ${resource}: wanted ${want}, got ${decision}"
  fi
}

with_boundary=(--context-entries "ContextKeyName=iam:PermissionsBoundary,ContextKeyValues=${boundary},ContextKeyType=string")

for who in sso plan apply; do
  check "$who" allow s3:GetObject "${state}/${project}/terraform.tfstate"
  check "$who" allow s3:PutObject "${state}/${project}/terraform.tfstate.tflock"
  for other in $others; do
    check "$who" deny s3:GetObject "${state}/${other}/terraform.tfstate"
    check "$who" deny ssm:GetParameter "arn:aws:ssm:${region}:${account}:parameter/${other}/x"
  done
  check "$who" deny iam:UpdateAssumeRolePolicy "$plan"
  check "$who" deny iam:UpdateAssumeRolePolicy "$apply"
  check "$who" deny iam:CreateRole "${iam}:role/${project}-x"
  check "$who" deny iam:CreateRole "${iam}:role/someone-else-x" "${with_boundary[@]}"
done

for who in sso apply; do
  check "$who" allow s3:PutObject "${state}/${project}/terraform.tfstate"
  check "$who" allow iam:CreateRole "${iam}:role/${project}-x" "${with_boundary[@]}"
  check "$who" deny iam:DeleteRolePermissionsBoundary "${iam}:role/${project}-x"
done

check plan deny s3:PutObject "${state}/${project}/terraform.tfstate"
check plan deny iam:CreateRole "${iam}:role/${project}-x" "${with_boundary[@]}"

if [ -n "$extra" ]; then
  while read -r who want action resource; do
    case "$who" in '' | \#*) continue ;; esac
    check "$who" "$want" "$action" "$resource"
  done <"$extra"
fi

echo "${project}: $((total - failed)) of ${total} as expected"
[ "$failed" -eq 0 ]
