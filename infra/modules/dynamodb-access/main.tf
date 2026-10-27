locals {
  tables           = [for name in var.tables : "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${name}"]
  data_resources   = concat(local.tables, [for table in local.tables : "${table}/index/*"])
  boundary_actions = var.boundary_actions == null ? var.data_actions : var.boundary_actions
}

data "aws_iam_policy_document" "boundary" {
  statement {
    sid       = "TableData"
    actions   = local.boundary_actions
    resources = local.data_resources
  }
}

data "aws_iam_policy_document" "read" {
  statement {
    sid       = "ReadTables"
    actions   = ["dynamodb:Describe*", "dynamodb:ListTagsOfResource", "dynamodb:GetResourcePolicy"]
    resources = local.tables
  }
}

data "aws_iam_policy_document" "write" {
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
    resources = local.tables
  }
}

data "aws_iam_policy_document" "operate" {
  statement {
    sid       = "TableData"
    actions   = concat(var.data_actions, ["dynamodb:DescribeTable"])
    resources = local.data_resources
  }
}
