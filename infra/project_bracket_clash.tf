locals {
  bracket_clash = {
    bucket       = "arn:aws:s3:::lj-bracket-clash"
    roles        = "arn:aws:iam::${local.account_id}:role/bracket-clash-*"
    state_key    = "${aws_s3_bucket.state.arn}/bracket-clash/terraform.tfstate"
    boundary_arn = "arn:aws:iam::${local.account_id}:policy/stych/bracket-clash-boundary"
  }
}

module "bracket_clash" {
  source = "./modules/project-access"

  name                  = "bracket-clash"
  github_subject_prefix = "repo:ljhurst/bracket-clash"
  account_id            = local.account_id
  oidc_provider_arn     = aws_iam_openid_connect_provider.github.arn
  sso_instance_arn      = local.sso_instance_arn
  sso_user_id           = local.sso_user_id

  boundary_policy_json = data.aws_iam_policy_document.bracket_clash_boundary.json
  read_policy_json     = data.aws_iam_policy_document.bracket_clash_read.json
  write_policy_json    = data.aws_iam_policy_document.bracket_clash_write.json
  operate_policy_json  = data.aws_iam_policy_document.bracket_clash_operate.json
}

import {
  to = module.bracket_clash.aws_ssoadmin_permission_set.deploy
  id = "arn:aws:sso:::permissionSet/ssoins-722334ffaa3b5076/ps-7223587f021a1e1e,${local.sso_instance_arn}"
}

import {
  to = module.bracket_clash.aws_ssoadmin_account_assignment.deploy
  id = "${local.sso_user_id},USER,${local.account_id},AWS_ACCOUNT,arn:aws:sso:::permissionSet/ssoins-722334ffaa3b5076/ps-7223587f021a1e1e,${local.sso_instance_arn}"
}

# The site has no workload roles; the module still requires a boundary.
data "aws_iam_policy_document" "bracket_clash_boundary" {
  statement {
    sid       = "ReadSite"
    actions   = ["s3:GetObject"]
    resources = ["${local.bracket_clash.bucket}/*"]
  }
}

data "aws_iam_policy_document" "bracket_clash_read" {
  statement {
    sid       = "ReadSiteBucket"
    actions   = ["s3:ListBucket", "s3:GetBucket*", "s3:GetAccelerateConfiguration", "s3:GetLifecycleConfiguration", "s3:GetReplicationConfiguration", "s3:GetEncryptionConfiguration"]
    resources = [local.bracket_clash.bucket]
  }

  statement {
    sid       = "ReadRoles"
    actions   = ["iam:GetRole", "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListRoleTags"]
    resources = [local.bracket_clash.roles]
  }

  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = [local.bracket_clash.state_key]
  }

  statement {
    sid       = "LockState"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.bracket_clash.state_key}.tflock"]
  }
}

data "aws_iam_policy_document" "bracket_clash_write" {
  statement {
    sid       = "ManageSiteBucket"
    actions   = ["s3:*"]
    resources = [local.bracket_clash.bucket]
  }

  statement {
    sid       = "DeploySite"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.bracket_clash.bucket}/*"]
  }

  statement {
    sid       = "WriteState"
    actions   = ["s3:PutObject"]
    resources = [local.bracket_clash.state_key]
  }

  statement {
    sid       = "GrantRolesOnlyWithinBoundary"
    actions   = ["iam:CreateRole", "iam:PutRolePolicy", "iam:AttachRolePolicy", "iam:PutRolePermissionsBoundary"]
    resources = [local.bracket_clash.roles]

    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [local.bracket_clash.boundary_arn]
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
    resources = [local.bracket_clash.roles]
  }

  statement {
    sid       = "KeepBoundary"
    effect    = "Deny"
    actions   = ["iam:DeleteRolePermissionsBoundary"]
    resources = [local.bracket_clash.roles]
  }
}

data "aws_iam_policy_document" "bracket_clash_operate" {
  statement {
    sid       = "ListSite"
    actions   = ["s3:ListBucket"]
    resources = [local.bracket_clash.bucket]
  }

  statement {
    sid       = "ManageSiteObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.bracket_clash.bucket}/*"]
  }
}
