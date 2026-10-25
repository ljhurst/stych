locals {
  train_spotting = {
    bucket       = "arn:aws:s3:::lj-train-spotting"
    roles        = "arn:aws:iam::${local.account_id}:role/train-spotting-*"
    state_key    = "${aws_s3_bucket.state.arn}/train-spotting/terraform.tfstate"
    boundary_arn = "arn:aws:iam::${local.account_id}:policy/stych/train-spotting-boundary"
  }
}

module "train_spotting" {
  source = "./modules/project-access"

  name                  = "train-spotting"
  github_subject_prefix = "repo:ljhurst/train-spotting"
  account_id            = local.account_id
  oidc_provider_arn     = aws_iam_openid_connect_provider.github.arn
  sso_instance_arn      = local.sso_instance_arn
  sso_user_id           = local.sso_user_id

  boundary_policy_json = data.aws_iam_policy_document.train_spotting_boundary.json
  read_policy_json     = data.aws_iam_policy_document.train_spotting_read.json
  write_policy_json    = data.aws_iam_policy_document.train_spotting_write.json
  operate_policy_json  = data.aws_iam_policy_document.train_spotting_operate.json
}

import {
  to = module.train_spotting.aws_ssoadmin_permission_set.deploy
  id = "arn:aws:sso:::permissionSet/ssoins-722334ffaa3b5076/ps-7223ca5dfb2805ee,${local.sso_instance_arn}"
}

import {
  to = module.train_spotting.aws_ssoadmin_account_assignment.deploy
  id = "${local.sso_user_id},USER,${local.account_id},AWS_ACCOUNT,arn:aws:sso:::permissionSet/ssoins-722334ffaa3b5076/ps-7223ca5dfb2805ee,${local.sso_instance_arn}"
}

# The site has no workload roles; the module still requires a boundary.
data "aws_iam_policy_document" "train_spotting_boundary" {
  statement {
    sid       = "ReadSite"
    actions   = ["s3:GetObject"]
    resources = ["${local.train_spotting.bucket}/*"]
  }
}

data "aws_iam_policy_document" "train_spotting_read" {
  statement {
    sid       = "ReadSiteBucket"
    actions   = ["s3:ListBucket", "s3:GetBucket*", "s3:GetAccelerateConfiguration", "s3:GetLifecycleConfiguration", "s3:GetReplicationConfiguration", "s3:GetEncryptionConfiguration"]
    resources = [local.train_spotting.bucket]
  }

  statement {
    sid       = "ReadRoles"
    actions   = ["iam:GetRole", "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListRoleTags"]
    resources = [local.train_spotting.roles]
  }

  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = [local.train_spotting.state_key]
  }

  statement {
    sid       = "LockState"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.train_spotting.state_key}.tflock"]
  }
}

data "aws_iam_policy_document" "train_spotting_write" {
  statement {
    sid       = "ManageSiteBucket"
    actions   = ["s3:*"]
    resources = [local.train_spotting.bucket]
  }

  statement {
    sid       = "DeploySite"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.train_spotting.bucket}/*"]
  }

  statement {
    sid       = "WriteState"
    actions   = ["s3:PutObject"]
    resources = [local.train_spotting.state_key]
  }

  statement {
    sid       = "GrantRolesOnlyWithinBoundary"
    actions   = ["iam:CreateRole", "iam:PutRolePolicy", "iam:AttachRolePolicy", "iam:PutRolePermissionsBoundary"]
    resources = [local.train_spotting.roles]

    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [local.train_spotting.boundary_arn]
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
    resources = [local.train_spotting.roles]
  }

  statement {
    sid       = "KeepBoundary"
    effect    = "Deny"
    actions   = ["iam:DeleteRolePermissionsBoundary"]
    resources = [local.train_spotting.roles]
  }
}

data "aws_iam_policy_document" "train_spotting_operate" {
  statement {
    sid       = "ListSite"
    actions   = ["s3:ListBucket"]
    resources = [local.train_spotting.bucket]
  }

  statement {
    sid       = "ManageSiteObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.train_spotting.bucket}/*"]
  }
}
