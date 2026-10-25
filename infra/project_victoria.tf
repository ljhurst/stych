locals {
  victoria = {
    functions    = "arn:aws:lambda:us-east-1:${local.account_id}:function:lj-victoria-*"
    log_group    = "arn:aws:logs:us-east-1:${local.account_id}:log-group:/aws/lambda/lj-victoria-*"
    roles        = "arn:aws:iam::${local.account_id}:role/victoria-*"
    groups       = "arn:aws:resource-groups:us-east-1:${local.account_id}:group/victoria-*"
    ssm_params   = "arn:aws:ssm:us-east-1:${local.account_id}:parameter/victoria/*"
    wiki_bucket  = "arn:aws:s3:::lj-victoria-wiki"
    state_key    = "${aws_s3_bucket.state.arn}/victoria/terraform.tfstate"
    boundary_arn = "arn:aws:iam::${local.account_id}:policy/stych/victoria-boundary"

    # Only the seed pages Terraform manages; CI never reads the rest of the wiki.
    managed_pages = [
      "arn:aws:s3:::lj-victoria-wiki/CONVENTIONS.md",
      "arn:aws:s3:::lj-victoria-wiki/index.md",
      "arn:aws:s3:::lj-victoria-wiki/log.md",
    ]
  }
}

module "victoria" {
  source = "./modules/project-access"

  name                  = "victoria"
  github_subject_prefix = "repo:ljhurst@9142868/victoria@1336851147"
  account_id            = local.account_id
  oidc_provider_arn     = aws_iam_openid_connect_provider.github.arn
  sso_instance_arn      = local.sso_instance_arn
  sso_user_id           = local.sso_user_id

  boundary_policy_json = data.aws_iam_policy_document.victoria_boundary.json
  read_policy_json     = data.aws_iam_policy_document.victoria_read.json
  write_policy_json    = data.aws_iam_policy_document.victoria_write.json
  operate_policy_json  = data.aws_iam_policy_document.victoria_operate.json
}

import {
  to = module.victoria.aws_ssoadmin_permission_set.deploy
  id = "arn:aws:sso:::permissionSet/ssoins-722334ffaa3b5076/ps-72232a2d2336e420,${local.sso_instance_arn}"
}

import {
  to = module.victoria.aws_ssoadmin_account_assignment.deploy
  id = "${local.sso_user_id},USER,${local.account_id},AWS_ACCOUNT,arn:aws:sso:::permissionSet/ssoins-722334ffaa3b5076/ps-72232a2d2336e420,${local.sso_instance_arn}"
}

data "aws_iam_policy_document" "victoria_boundary" {
  statement {
    sid       = "ListWiki"
    actions   = ["s3:ListBucket"]
    resources = [local.victoria.wiki_bucket]
  }

  statement {
    sid       = "ReadWriteWiki"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${local.victoria.wiki_bucket}/*"]
  }

  statement {
    sid       = "ReadParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [local.victoria.ssm_params]
  }

  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [local.victoria.log_group, "${local.victoria.log_group}:*"]
  }
}

data "aws_iam_policy_document" "victoria_read" {
  statement {
    sid       = "ReadFunctions"
    actions   = ["lambda:Get*", "lambda:List*"]
    resources = [local.victoria.functions]
  }

  statement {
    sid       = "ReadWikiBucket"
    actions   = ["s3:GetBucket*", "s3:GetAccelerateConfiguration", "s3:GetLifecycleConfiguration", "s3:GetReplicationConfiguration", "s3:GetEncryptionConfiguration"]
    resources = [local.victoria.wiki_bucket]
  }

  statement {
    sid       = "ReadManagedPages"
    actions   = ["s3:GetObject", "s3:GetObjectTagging", "s3:GetObjectAcl"]
    resources = local.victoria.managed_pages
  }

  statement {
    sid       = "ListLogGroups"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  statement {
    sid       = "ReadLogGroups"
    actions   = ["logs:ListTagsForResource", "logs:ListTagsLogGroup"]
    resources = [local.victoria.log_group, "${local.victoria.log_group}:*"]
  }

  statement {
    sid       = "ReadRoles"
    actions   = ["iam:GetRole", "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListRoleTags"]
    resources = [local.victoria.roles]
  }

  statement {
    sid       = "ReadResourceGroups"
    actions   = ["resource-groups:Get*", "resource-groups:List*"]
    resources = [local.victoria.groups]
  }

  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = [local.victoria.state_key]
  }

  statement {
    sid       = "LockState"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.victoria.state_key}.tflock"]
  }
}

data "aws_iam_policy_document" "victoria_write" {
  statement {
    sid       = "ManageFunctions"
    actions   = ["lambda:*"]
    resources = [local.victoria.functions]
  }

  statement {
    sid       = "ManageWikiBucket"
    actions   = ["s3:*"]
    resources = [local.victoria.wiki_bucket]
  }

  statement {
    sid       = "ManageManagedPages"
    actions   = ["s3:PutObject", "s3:DeleteObject", "s3:PutObjectTagging"]
    resources = local.victoria.managed_pages
  }

  statement {
    sid       = "ManageLogGroups"
    actions   = ["logs:*"]
    resources = [local.victoria.log_group, "${local.victoria.log_group}:*"]
  }

  statement {
    sid       = "ManageResourceGroups"
    actions   = ["resource-groups:*"]
    resources = [local.victoria.groups]
  }

  statement {
    sid       = "WriteState"
    actions   = ["s3:PutObject"]
    resources = [local.victoria.state_key]
  }

  statement {
    sid       = "GrantRolesOnlyWithinBoundary"
    actions   = ["iam:CreateRole", "iam:PutRolePolicy", "iam:AttachRolePolicy", "iam:PutRolePermissionsBoundary"]
    resources = [local.victoria.roles]

    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [local.victoria.boundary_arn]
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
    resources = [local.victoria.roles]
  }

  statement {
    sid       = "PassRolesToLambda"
    actions   = ["iam:PassRole"]
    resources = [local.victoria.roles]

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
    resources = [local.victoria.roles]
  }
}

data "aws_iam_policy_document" "victoria_operate" {
  statement {
    sid       = "ListWiki"
    actions   = ["s3:ListBucket"]
    resources = [local.victoria.wiki_bucket]
  }

  statement {
    sid       = "ManageWikiPages"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.victoria.wiki_bucket}/*"]
  }

  statement {
    sid       = "ManageParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:PutParameter", "ssm:GetParameterHistory"]
    resources = [local.victoria.ssm_params]
  }

  statement {
    sid       = "ReadLogs"
    actions   = ["logs:FilterLogEvents", "logs:GetLogEvents", "logs:DescribeLogStreams", "logs:StartQuery", "logs:StopQuery"]
    resources = [local.victoria.log_group, "${local.victoria.log_group}:*"]
  }

  statement {
    sid       = "QueryResults"
    actions   = ["logs:GetQueryResults", "logs:DescribeQueries"]
    resources = ["*"]
  }
}
