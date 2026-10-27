#!/usr/bin/env bash
# Sets a new random origin-verify secret for one Function URL site: in the shared
# CloudFront key value store under the site's hostname, and in the SSM parameter
# the origin reads. Neither value is printed or passed on a command line, and
# Terraform never sees it. Rerun to rotate: until the origin enforces the check
# nothing breaks, afterwards requests fail until both copies match.
#
# Usage: scripts/set-origin-verify.sh <hostname> <ssm-parameter>
#   e.g. scripts/set-origin-verify.sh lasso.bylukehurst.com /lasso/origin-verify
#
# Needs admin credentials (cloudfront-keyvaluestore:PutKey, ssm:PutParameter), jq
# and an AWS CLI with CRT support for the key value store API.
set -euo pipefail

host=${1:?usage: $0 <hostname> <ssm-parameter>}
parameter=${2:?usage: $0 <hostname> <ssm-parameter>}

cd "$(dirname "$0")/.."

kvs_arn=$(terraform -chdir=infra output -raw origin_verify_kvs_arn)
etag=$(aws cloudfront-keyvaluestore describe-key-value-store --kvs-arn "$kvs_arn" --query ETag --output text)
secret=$(openssl rand -hex 32)

# The AWS CLI cannot read --cli-input-json from a pipe, so the payload goes through a
# temporary file that only this user can read; it is removed on exit.
payload=$(mktemp)
trap 'rm -f "$payload"' EXIT

jq -n --arg arn "$kvs_arn" --arg key "$host" --arg value "$secret" --arg etag "$etag" \
  '{KvsARN: $arn, Key: $key, Value: $value, IfMatch: $etag}' >"$payload"
aws cloudfront-keyvaluestore put-key --cli-input-json "file://$payload" >/dev/null

jq -n --arg name "$parameter" --arg value "$secret" \
  '{Name: $name, Value: $value, Type: "SecureString", Overwrite: true}' >"$payload"
aws ssm put-parameter --cli-input-json "file://$payload" >/dev/null

echo "Set the origin-verify secret for ${host} in the key value store and in ${parameter}."
