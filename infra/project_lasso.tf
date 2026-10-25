locals {
  lasso = {
    functions      = "arn:aws:lambda:us-east-1:${local.account_id}:function:lj-lasso*"
    lwa_layer      = "arn:aws:lambda:us-east-1:753240598075:layer:LambdaAdapterLayerArm64:*"
    tables         = "arn:aws:dynamodb:us-east-1:${local.account_id}:table/lj-lasso*"
    log_group      = "arn:aws:logs:us-east-1:${local.account_id}:log-group:/aws/lambda/lj-lasso*"
    roles          = "arn:aws:iam::${local.account_id}:role/lasso-*"
    groups         = "arn:aws:resource-groups:us-east-1:${local.account_id}:group/lasso-*"
    ssm_params     = "arn:aws:ssm:us-east-1:${local.account_id}:parameter/lasso/*"
    state_key      = "${aws_s3_bucket.state.arn}/lasso/terraform.tfstate"
    boundary_arn   = "arn:aws:iam::${local.account_id}:policy/stych/lasso-boundary"
    table_data_ops = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:BatchGetItem", "dynamodb:BatchWriteItem", "dynamodb:ConditionCheckItem"]
  }
}

module "lasso" {
  source = "./modules/project-access"

  name                  = "lasso"
  github_subject_prefix = "repo:ljhurst@9142868/lasso@1341558720"
  account_id            = local.account_id
  oidc_provider_arn     = aws_iam_openid_connect_provider.github.arn
  sso_instance_arn      = local.sso_instance_arn
  sso_user_id           = local.sso_user_id

  boundary_policy_json = data.aws_iam_policy_document.lasso_boundary.json
  read_policy_json     = data.aws_iam_policy_document.lasso_read.json
  write_policy_json    = data.aws_iam_policy_document.lasso_write.json
  operate_policy_json  = data.aws_iam_policy_document.lasso_operate.json
}

import {
  to = module.lasso.aws_ssoadmin_permission_set.deploy
  id = "arn:aws:sso:::permissionSet/ssoins-722334ffaa3b5076/ps-7223ad5bd31dc2ae,${local.sso_instance_arn}"
}

import {
  to = module.lasso.aws_ssoadmin_account_assignment.deploy
  id = "${local.sso_user_id},USER,${local.account_id},AWS_ACCOUNT,arn:aws:sso:::permissionSet/ssoins-722334ffaa3b5076/ps-7223ad5bd31dc2ae,${local.sso_instance_arn}"
}

data "aws_iam_policy_document" "lasso_boundary" {
  statement {
    sid       = "TableData"
    actions   = local.lasso.table_data_ops
    resources = [local.lasso.tables, "${local.lasso.tables}/index/*"]
  }

  statement {
    sid       = "ReadParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [local.lasso.ssm_params]
  }

  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [local.lasso.log_group, "${local.lasso.log_group}:*"]
  }
}

data "aws_iam_policy_document" "lasso_read" {
  statement {
    sid       = "ReadFunctions"
    actions   = ["lambda:Get*", "lambda:List*"]
    resources = [local.lasso.functions]
  }

  statement {
    sid       = "ReadAdapterLayer"
    actions   = ["lambda:GetLayerVersion"]
    resources = [local.lasso.lwa_layer]
  }

  statement {
    sid       = "ReadTables"
    actions   = ["dynamodb:Describe*", "dynamodb:ListTagsOfResource", "dynamodb:GetResourcePolicy"]
    resources = [local.lasso.tables]
  }

  statement {
    sid       = "ListLogGroups"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  statement {
    sid       = "ReadLogGroup"
    actions   = ["logs:ListTagsForResource", "logs:ListTagsLogGroup"]
    resources = [local.lasso.log_group, "${local.lasso.log_group}:*"]
  }

  statement {
    sid       = "ReadRoles"
    actions   = ["iam:GetRole", "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListRoleTags"]
    resources = [local.lasso.roles]
  }

  statement {
    sid       = "ReadResourceGroups"
    actions   = ["resource-groups:Get*", "resource-groups:List*"]
    resources = [local.lasso.groups]
  }

  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = [local.lasso.state_key]
  }

  statement {
    sid       = "LockState"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.lasso.state_key}.tflock"]
  }
}

data "aws_iam_policy_document" "lasso_write" {
  statement {
    sid       = "ManageFunctions"
    actions   = ["lambda:*"]
    resources = [local.lasso.functions]
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
    resources = [local.lasso.tables]
  }

  statement {
    sid       = "ManageLogGroup"
    actions   = ["logs:*"]
    resources = [local.lasso.log_group, "${local.lasso.log_group}:*"]
  }

  statement {
    sid       = "ManageResourceGroups"
    actions   = ["resource-groups:*"]
    resources = [local.lasso.groups]
  }

  statement {
    sid       = "WriteState"
    actions   = ["s3:PutObject"]
    resources = [local.lasso.state_key]
  }

  statement {
    sid       = "GrantRolesOnlyWithinBoundary"
    actions   = ["iam:CreateRole", "iam:PutRolePolicy", "iam:AttachRolePolicy", "iam:PutRolePermissionsBoundary"]
    resources = [local.lasso.roles]

    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [local.lasso.boundary_arn]
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
    resources = [local.lasso.roles]
  }

  statement {
    sid       = "PassRolesToLambda"
    actions   = ["iam:PassRole"]
    resources = [local.lasso.roles]

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
    resources = [local.lasso.roles]
  }
}

data "aws_iam_policy_document" "lasso_operate" {
  statement {
    sid       = "TableData"
    actions   = concat(local.lasso.table_data_ops, ["dynamodb:DescribeTable"])
    resources = [local.lasso.tables, "${local.lasso.tables}/index/*"]
  }

  statement {
    sid       = "ManageParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:PutParameter", "ssm:GetParameterHistory"]
    resources = [local.lasso.ssm_params]
  }

  statement {
    sid       = "ReadLogs"
    actions   = ["logs:FilterLogEvents", "logs:GetLogEvents", "logs:DescribeLogStreams", "logs:StartQuery", "logs:StopQuery"]
    resources = [local.lasso.log_group, "${local.lasso.log_group}:*"]
  }

  statement {
    sid       = "QueryResults"
    actions   = ["logs:GetQueryResults", "logs:DescribeQueries"]
    resources = ["*"]
  }
}
