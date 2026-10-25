locals {
  policies = {
    boundary = var.boundary_policy_json
    read     = var.read_policy_json
    write    = var.write_policy_json
    operate  = var.operate_policy_json
  }

  # The deploy policy (read + write) is shared by people and CI so the two
  # can't drift; operate is only for people.
  role_policies = {
    plan  = ["read"]
    apply = ["read", "write"]
  }
  permission_set_policies = ["read", "write", "operate"]

  ci_subjects = {
    plan  = "repo:${var.repo}:pull_request"
    apply = "repo:${var.repo}:environment:prod"
  }
}

resource "aws_iam_policy" "this" {
  for_each = local.policies

  name   = "${var.name}-${each.key == "boundary" ? "boundary" : "deploy-${each.key}"}"
  path   = "/stych/"
  policy = each.value
}

resource "aws_iam_role" "ci" {
  for_each = local.ci_subjects

  name               = "${var.name}-ci-${each.key}"
  path               = "/stych/"
  assume_role_policy = data.aws_iam_policy_document.ci_trust[each.key].json
}

data "aws_iam_policy_document" "ci_trust" {
  for_each = local.ci_subjects

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [each.value]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ci" {
  for_each = {
    for pair in flatten([
      for role, policies in local.role_policies : [
        for policy in policies : { role = role, policy = policy }
      ]
    ]) : "${pair.role}-${pair.policy}" => pair
  }

  role       = aws_iam_role.ci[each.value.role].name
  policy_arn = aws_iam_policy.this[each.value.policy].arn
}

resource "aws_ssoadmin_permission_set" "deploy" {
  name             = "${var.name}-deploy"
  description      = "Local deploy and operate access for ${var.name}, managed by stych"
  instance_arn     = var.sso_instance_arn
  session_duration = "PT4H"
}

resource "aws_ssoadmin_customer_managed_policy_attachment" "deploy" {
  for_each = toset(local.permission_set_policies)

  instance_arn       = var.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.deploy.arn

  customer_managed_policy_reference {
    name = aws_iam_policy.this[each.key].name
    path = aws_iam_policy.this[each.key].path
  }
}

resource "aws_ssoadmin_account_assignment" "deploy" {
  instance_arn       = var.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.deploy.arn
  principal_id       = var.sso_user_id
  principal_type     = "USER"
  target_id          = var.account_id
  target_type        = "AWS_ACCOUNT"
}
