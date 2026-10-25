locals {
  porto = {
    functions      = "arn:aws:lambda:us-east-1:${local.account_id}:function:lj-porto-mcp*"
    lwa_layer      = "arn:aws:lambda:us-east-1:753240598075:layer:LambdaAdapterLayerArm64:*"
    locks_table    = "arn:aws:dynamodb:us-east-1:${local.account_id}:table/porto-locks"
    log_group      = "arn:aws:logs:us-east-1:${local.account_id}:log-group:/aws/lambda/lj-porto-mcp*"
    roles          = "arn:aws:iam::${local.account_id}:role/porto-*"
    groups         = "arn:aws:resource-groups:us-east-1:${local.account_id}:group/porto-*"
    ssm_params     = "arn:aws:ssm:us-east-1:${local.account_id}:parameter/porto/*"
    session_param  = "arn:aws:ssm:us-east-1:${local.account_id}:parameter/porto/sommething/session"
    state_key      = "${aws_s3_bucket.state.arn}/porto/terraform.tfstate"
    boundary_arn   = "arn:aws:iam::${local.account_id}:policy/stych/porto-boundary"
    table_data_ops = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:ConditionCheckItem"]
  }
}

module "porto" {
  source = "./modules/project-access"

  name                  = "porto"
  github_subject_prefix = "repo:ljhurst@9142868/porto@1336875812"
  account_id            = local.account_id
  oidc_provider_arn     = aws_iam_openid_connect_provider.github.arn
  sso_instance_arn      = local.sso_instance_arn
  sso_user_id           = local.sso_user_id

  boundary_policy_json = data.aws_iam_policy_document.porto_boundary.json
  read_policy_json     = data.aws_iam_policy_document.porto_read.json
  write_policy_json    = data.aws_iam_policy_document.porto_write.json
  operate_policy_json  = data.aws_iam_policy_document.porto_operate.json
}

import {
  to = module.porto.aws_ssoadmin_permission_set.deploy
  id = "arn:aws:sso:::permissionSet/ssoins-722334ffaa3b5076/ps-72232d3190ed37b2,${local.sso_instance_arn}"
}

import {
  to = module.porto.aws_ssoadmin_account_assignment.deploy
  id = "${local.sso_user_id},USER,${local.account_id},AWS_ACCOUNT,arn:aws:sso:::permissionSet/ssoins-722334ffaa3b5076/ps-72232d3190ed37b2,${local.sso_instance_arn}"
}

data "aws_iam_policy_document" "porto_boundary" {
  statement {
    sid       = "ReadParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [local.porto.ssm_params]
  }

  statement {
    sid       = "RotateSession"
    actions   = ["ssm:PutParameter"]
    resources = [local.porto.session_param]
  }

  statement {
    sid       = "TokenRefreshLock"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem"]
    resources = [local.porto.locks_table]
  }

  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [local.porto.log_group, "${local.porto.log_group}:*"]
  }
}

data "aws_iam_policy_document" "porto_read" {
  statement {
    sid       = "ReadFunctions"
    actions   = ["lambda:Get*", "lambda:List*"]
    resources = [local.porto.functions]
  }

  statement {
    sid       = "ReadAdapterLayer"
    actions   = ["lambda:GetLayerVersion"]
    resources = [local.porto.lwa_layer]
  }

  statement {
    sid       = "ReadTables"
    actions   = ["dynamodb:Describe*", "dynamodb:ListTagsOfResource", "dynamodb:GetResourcePolicy"]
    resources = [local.porto.locks_table]
  }

  statement {
    sid       = "ListLogGroups"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  statement {
    sid       = "ReadLogGroup"
    actions   = ["logs:ListTagsForResource", "logs:ListTagsLogGroup"]
    resources = [local.porto.log_group, "${local.porto.log_group}:*"]
  }

  statement {
    sid       = "ReadRoles"
    actions   = ["iam:GetRole", "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListRoleTags"]
    resources = [local.porto.roles]
  }

  statement {
    sid       = "ReadResourceGroups"
    actions   = ["resource-groups:Get*", "resource-groups:List*"]
    resources = [local.porto.groups]
  }

  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = [local.porto.state_key]
  }

  statement {
    sid       = "LockState"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.porto.state_key}.tflock"]
  }
}

data "aws_iam_policy_document" "porto_write" {
  statement {
    sid       = "ManageFunctions"
    actions   = ["lambda:*"]
    resources = [local.porto.functions]
  }

  statement {
    sid = "ManageTables"
    actions = [
      "dynamodb:CreateTable",
      "dynamodb:UpdateTable",
      "dynamodb:DeleteTable",
      "dynamodb:TagResource",
      "dynamodb:UntagResource",
      "dynamodb:UpdateTimeToLive",
      "dynamodb:UpdateContinuousBackups",
      "dynamodb:PutResourcePolicy",
      "dynamodb:DeleteResourcePolicy",
    ]
    resources = [local.porto.locks_table]
  }

  statement {
    sid       = "ManageLogGroup"
    actions   = ["logs:*"]
    resources = [local.porto.log_group, "${local.porto.log_group}:*"]
  }

  statement {
    sid       = "ManageResourceGroups"
    actions   = ["resource-groups:*"]
    resources = [local.porto.groups]
  }

  statement {
    sid       = "WriteState"
    actions   = ["s3:PutObject"]
    resources = [local.porto.state_key]
  }

  statement {
    sid       = "GrantRolesOnlyWithinBoundary"
    actions   = ["iam:CreateRole", "iam:PutRolePolicy", "iam:AttachRolePolicy", "iam:PutRolePermissionsBoundary"]
    resources = [local.porto.roles]

    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [local.porto.boundary_arn]
    }
  }

  statement {
    sid = "ManageRoles"
    actions = [
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
    ]
    resources = [local.porto.roles]
  }

  statement {
    sid       = "PassRolesToLambda"
    actions   = ["iam:PassRole"]
    resources = [local.porto.roles]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
  }

  statement {
    sid       = "KeepBoundary"
    effect    = "Deny"
    actions   = ["iam:DeleteRolePermissionsBoundary"]
    resources = [local.porto.roles]
  }
}

data "aws_iam_policy_document" "porto_operate" {
  statement {
    sid       = "LockTableData"
    actions   = concat(local.porto.table_data_ops, ["dynamodb:DescribeTable"])
    resources = [local.porto.locks_table]
  }

  statement {
    sid       = "ManageParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:PutParameter", "ssm:GetParameterHistory"]
    resources = [local.porto.ssm_params]
  }

  statement {
    sid       = "ReadLogs"
    actions   = ["logs:FilterLogEvents", "logs:GetLogEvents", "logs:DescribeLogStreams", "logs:StartQuery", "logs:StopQuery"]
    resources = [local.porto.log_group, "${local.porto.log_group}:*"]
  }

  statement {
    sid       = "QueryResults"
    actions   = ["logs:GetQueryResults", "logs:DescribeQueries"]
    resources = ["*"]
  }
}
