locals {
  groups = "arn:aws:resource-groups:${var.region}:${var.account_id}:group/${var.project}-*"
}

data "aws_iam_policy_document" "read" {
  statement {
    sid       = "ReadResourceGroups"
    actions   = ["resource-groups:Get*", "resource-groups:List*"]
    resources = [local.groups]
  }
}

data "aws_iam_policy_document" "write" {
  statement {
    sid       = "ManageResourceGroups"
    actions   = ["resource-groups:*"]
    resources = [local.groups]
  }
}
