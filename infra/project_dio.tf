locals {
  dio = {
    function       = "arn:aws:lambda:${local.region}:${local.account_id}:function:lj-dio-extract"
    functions      = "arn:aws:lambda:${local.region}:${local.account_id}:function:lj-dio-*"
    log_group      = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/lj-dio-*"
    roles          = "arn:aws:iam::${local.account_id}:role/dio-*"
    ssm_params     = "arn:aws:ssm:${local.region}:${local.account_id}:parameter/dio/*"
    vercel_oidc    = "arn:aws:iam::${local.account_id}:oidc-provider/oidc.vercel.com/ljhursts-projects"
    legacy_roles   = [for r in ["lj-dio-lambda-exec", "lj-dio-github-actions-deploy", "lj-dio-sommething-invoke"] : "arn:aws:iam::${local.account_id}:role/${r}"]
    permission_set = "arn:aws:sso:::permissionSet/ssoins-722334ffaa3b5076/ps-722309dd972cb8bb"
  }
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
  operate_policy_json  = data.aws_iam_policy_document.dio_operate.json
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
  statement {
    sid       = "ReadParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [local.dio.ssm_params]
  }

  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [local.dio.log_group, "${local.dio.log_group}:*"]
  }

  statement {
    sid       = "InvokeFunction"
    actions   = ["lambda:InvokeFunctionUrl", "lambda:InvokeFunction"]
    resources = [local.dio.function]
  }
}

data "aws_iam_policy_document" "dio_read" {
  statement {
    sid       = "ReadFunctions"
    actions   = ["lambda:Get*", "lambda:List*"]
    resources = [local.dio.functions]
  }

  statement {
    sid       = "ListLogGroups"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  statement {
    sid       = "ReadLogGroups"
    actions   = ["logs:ListTagsForResource", "logs:ListTagsLogGroup"]
    resources = [local.dio.log_group, "${local.dio.log_group}:*"]
  }

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
  statement {
    sid       = "ManageFunctions"
    actions   = ["lambda:*"]
    resources = [local.dio.functions]
  }

  statement {
    sid       = "ManageLogGroups"
    actions   = ["logs:*"]
    resources = [local.dio.log_group, "${local.dio.log_group}:*"]
  }

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

  statement {
    sid       = "PassRolesToLambda"
    actions   = ["iam:PassRole"]
    resources = [local.dio.roles]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
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

data "aws_iam_policy_document" "dio_operate" {
  statement {
    sid       = "ManageParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:PutParameter", "ssm:GetParameterHistory"]
    resources = [local.dio.ssm_params]
  }

  statement {
    sid       = "ReadLogs"
    actions   = ["logs:FilterLogEvents", "logs:GetLogEvents", "logs:DescribeLogStreams", "logs:StartQuery", "logs:StopQuery"]
    resources = [local.dio.log_group, "${local.dio.log_group}:*"]
  }

  statement {
    sid       = "QueryResults"
    actions   = ["logs:GetQueryResults", "logs:DescribeQueries"]
    resources = ["*"]
  }
}
