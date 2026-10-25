data "aws_iam_policy_document" "read" {
  source_policy_documents = [data.aws_iam_policy_document.common_read.json, var.read_policy_json]
}

data "aws_iam_policy_document" "write" {
  source_policy_documents = [data.aws_iam_policy_document.common_write.json, var.write_policy_json]
}

data "aws_iam_policy_document" "common_read" {
  statement {
    sid       = "ReadRoles"
    actions   = ["iam:GetRole", "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListRoleTags"]
    resources = [local.roles]
  }

  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [var.state_bucket_arn]
  }

  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = [local.state_key]
  }

  statement {
    sid       = "LockState"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_key}.tflock"]
  }
}

data "aws_iam_policy_document" "common_write" {
  statement {
    sid       = "WriteState"
    actions   = ["s3:PutObject"]
    resources = [local.state_key]
  }

  statement {
    sid       = "GrantRolesOnlyWithinBoundary"
    actions   = ["iam:CreateRole", "iam:PutRolePolicy", "iam:AttachRolePolicy", "iam:PutRolePermissionsBoundary"]
    resources = [local.roles]

    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [local.boundary_arn]
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
      "iam:ListInstanceProfilesForRole",
    ]
    resources = [local.roles]
  }

  statement {
    sid       = "KeepBoundary"
    effect    = "Deny"
    actions   = ["iam:DeleteRolePermissionsBoundary"]
    resources = [local.roles]
  }
}
