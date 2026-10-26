locals {
  dio = {
    function       = "arn:aws:lambda:${local.region}:${local.account_id}:function:lj-dio-extract"
    vercel_oidc    = "arn:aws:iam::${local.account_id}:oidc-provider/oidc.vercel.com/ljhursts-projects"
    legacy_roles   = [for r in ["lj-dio-lambda-exec", "lj-dio-github-actions-deploy", "lj-dio-sommething-invoke"] : "arn:aws:iam::${local.account_id}:role/${r}"]
    permission_set = "arn:aws:sso:::permissionSet/ssoins-722334ffaa3b5076/ps-722309dd972cb8bb"
  }
}

module "dio_lambda_access" {
  source = "./modules/lambda-access"

  project          = "dio"
  account_id       = local.account_id
  region           = local.region
  function_pattern = "lj-dio-*"
  resource_groups  = false
}

module "dio" {
  source = "./modules/project-access"

  name                  = "dio"
  github_subject_prefix = "repo:ljhurst@9142868/dio@1315850400"
  account_id            = local.account_id
  oidc_provider_arn     = aws_iam_openid_connect_provider.github.arn
  sso_instance_arn      = local.sso_instance_arn
  sso_user_id           = local.sso_user_id
  state_bucket_arn      = aws_s3_bucket.state.arn

  boundary_policy_json = data.aws_iam_policy_document.dio_boundary.json
  read_policy_json     = data.aws_iam_policy_document.dio_read.json
  write_policy_json    = data.aws_iam_policy_document.dio_write.json
  operate_policy_json  = module.dio_lambda_access.operate_policy_json
}

import {
  to = module.dio.aws_ssoadmin_permission_set.deploy
  id = "${local.dio.permission_set},${local.sso_instance_arn}"
}

import {
  to = module.dio.aws_ssoadmin_account_assignment.deploy
  id = "${local.sso_user_id},USER,${local.account_id},AWS_ACCOUNT,${local.dio.permission_set},${local.sso_instance_arn}"
}

data "aws_iam_policy_document" "dio_boundary" {
  source_policy_documents = [module.dio_lambda_access.boundary_policy_json]

  statement {
    sid       = "InvokeFunction"
    actions   = ["lambda:InvokeFunctionUrl", "lambda:InvokeFunction"]
    resources = [local.dio.function]
  }
}

data "aws_iam_policy_document" "dio_read" {
  source_policy_documents = [module.dio_lambda_access.read_policy_json]

  statement {
    sid       = "ReadVercelProvider"
    actions   = ["iam:GetOpenIDConnectProvider", "iam:ListOpenIDConnectProviderTags"]
    resources = [local.dio.vercel_oidc]
  }

  # The roles dio defined before joining stych, until the first CI apply removes them.
  statement {
    sid       = "ReadLegacyRoles"
    actions   = ["iam:GetRole", "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListRoleTags"]
    resources = local.dio.legacy_roles
  }
}

data "aws_iam_policy_document" "dio_write" {
  source_policy_documents = [module.dio_lambda_access.write_policy_json]

  statement {
    sid = "ManageVercelProvider"
    actions = [
      "iam:AddClientIDToOpenIDConnectProvider",
      "iam:RemoveClientIDFromOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:TagOpenIDConnectProvider",
      "iam:UntagOpenIDConnectProvider",
    ]
    resources = [local.dio.vercel_oidc]
  }

  # Removed once the first CI apply has deleted the roles dio defined before joining stych.
  statement {
    sid = "RemoveLegacyRoles"
    actions = [
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:ListInstanceProfilesForRole",
    ]
    resources = local.dio.legacy_roles
  }
}
