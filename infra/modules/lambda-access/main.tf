locals {
  functions  = "arn:aws:lambda:${var.region}:${var.account_id}:function:${var.function_pattern}"
  log_group  = "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/lambda/${var.function_pattern}"
  roles      = "arn:aws:iam::${var.account_id}:role/${var.project}-*"
  ssm_params = "arn:aws:ssm:${var.region}:${var.account_id}:parameter/${var.project}/*"

  writable_params = [
    for name in var.writable_parameters :
    "arn:aws:ssm:${var.region}:${var.account_id}:parameter/${var.project}/${name}"
  ]

  deletable_params = [
    for name in var.deletable_parameters :
    "arn:aws:ssm:${var.region}:${var.account_id}:parameter/${var.project}/${name}"
  ]
}

data "aws_iam_policy_document" "boundary" {
  statement {
    sid       = "ReadParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [local.ssm_params]
  }

  dynamic "statement" {
    for_each = length(local.writable_params) == 0 ? [] : [1]

    content {
      sid       = "WriteParameters"
      actions   = ["ssm:PutParameter"]
      resources = local.writable_params
    }
  }

  dynamic "statement" {
    for_each = length(local.deletable_params) == 0 ? [] : [1]

    content {
      sid       = "DeleteParameters"
      actions   = ["ssm:DeleteParameter"]
      resources = local.deletable_params
    }
  }

  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [local.log_group, "${local.log_group}:*"]
  }
}

data "aws_iam_policy_document" "read" {
  statement {
    sid       = "ReadFunctions"
    actions   = ["lambda:Get*", "lambda:List*"]
    resources = [local.functions]
  }

  statement {
    sid       = "ListLogGroups"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  statement {
    sid       = "ReadLogGroups"
    actions   = ["logs:ListTagsForResource", "logs:ListTagsLogGroup"]
    resources = [local.log_group, "${local.log_group}:*"]
  }
}

data "aws_iam_policy_document" "write" {
  statement {
    sid       = "ManageFunctions"
    actions   = ["lambda:*"]
    resources = [local.functions]
  }

  statement {
    sid       = "ManageLogGroups"
    actions   = ["logs:*"]
    resources = [local.log_group, "${local.log_group}:*"]
  }

  statement {
    sid       = "PassRolesToLambda"
    actions   = ["iam:PassRole"]
    resources = [local.roles]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "operate" {
  statement {
    sid       = "ManageParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:PutParameter", "ssm:GetParameterHistory"]
    resources = [local.ssm_params]
  }

  dynamic "statement" {
    for_each = length(local.deletable_params) == 0 ? [] : [1]

    content {
      sid       = "DeleteParameters"
      actions   = ["ssm:DeleteParameter"]
      resources = local.deletable_params
    }
  }

  statement {
    sid       = "ReadLogs"
    actions   = ["logs:FilterLogEvents", "logs:GetLogEvents", "logs:DescribeLogStreams", "logs:StartQuery", "logs:StopQuery"]
    resources = [local.log_group, "${local.log_group}:*"]
  }

  statement {
    sid       = "QueryResults"
    actions   = ["logs:GetQueryResults", "logs:DescribeQueries"]
    resources = ["*"]
  }
}
