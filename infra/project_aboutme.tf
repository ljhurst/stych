locals {
  aboutme = {
    permission_set = "arn:aws:sso:::permissionSet/ssoins-722334ffaa3b5076/ps-7223d4bb1946499b"
    api = [
      "arn:aws:apigateway:${local.region}::/restapis",
      "arn:aws:apigateway:${local.region}::/restapis/*",
      "arn:aws:apigateway:${local.region}::/tags/*",
    ]
    legacy_roles = [for r in ["lj-aboutme-lambda-exec", "lj-aboutme-github-actions-backend-deploy", "lj-aboutme-github-actions-frontend-deploy"] : "arn:aws:iam::${local.account_id}:role/${r}"]
  }
}

module "aboutme_lambda_access" {
  source = "./modules/lambda-access"

  project          = "aboutme"
  account_id       = local.account_id
  region           = local.region
  function_pattern = "lj-aboutme-*"
  resource_groups  = false
}

module "aboutme_site_access" {
  source = "./modules/static-site-access"

  project         = "aboutme"
  bucket_name     = "lj-aboutme"
  account_id      = local.account_id
  certificate_arn = aws_acm_certificate.wildcard.arn
}

module "aboutme" {
  source = "./modules/project-access"

  name                  = "aboutme"
  github_subject_prefix = "repo:ljhurst/aboutme"
  account_id            = local.account_id
  oidc_provider_arn     = aws_iam_openid_connect_provider.github.arn
  sso_instance_arn      = local.sso_instance_arn
  sso_user_id           = local.sso_user_id
  state_bucket_arn      = aws_s3_bucket.state.arn

  boundary_policy_json = module.aboutme_lambda_access.boundary_policy_json
  read_policy_json     = data.aws_iam_policy_document.aboutme_read.json
  write_policy_json    = data.aws_iam_policy_document.aboutme_write.json
  operate_policy_json  = data.aws_iam_policy_document.aboutme_operate.json
}

import {
  to = module.aboutme.aws_ssoadmin_permission_set.deploy
  id = "${local.aboutme.permission_set},${local.sso_instance_arn}"
}

import {
  to = module.aboutme.aws_ssoadmin_account_assignment.deploy
  id = "${local.sso_user_id},USER,${local.account_id},AWS_ACCOUNT,${local.aboutme.permission_set},${local.sso_instance_arn}"
}

data "aws_iam_policy_document" "aboutme_read" {
  source_policy_documents = [module.aboutme_site_access.read_policy_json, module.aboutme_lambda_access.read_policy_json]

  statement {
    sid       = "ReadApi"
    actions   = ["apigateway:GET"]
    resources = local.aboutme.api
  }

  # The roles aboutme defined before joining stych, until the first CI apply removes them.
  statement {
    sid       = "ReadLegacyRoles"
    actions   = ["iam:GetRole", "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListRoleTags"]
    resources = local.aboutme.legacy_roles
  }
}

data "aws_iam_policy_document" "aboutme_write" {
  source_policy_documents = [module.aboutme_site_access.write_policy_json, module.aboutme_lambda_access.write_policy_json]

  statement {
    sid       = "ManageApi"
    actions   = ["apigateway:*"]
    resources = local.aboutme.api
  }

  # Removed once the first CI apply has deleted the roles aboutme defined before joining stych.
  statement {
    sid = "RemoveLegacyRoles"
    actions = [
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:ListInstanceProfilesForRole",
    ]
    resources = local.aboutme.legacy_roles
  }
}

data "aws_iam_policy_document" "aboutme_operate" {
  source_policy_documents = [module.aboutme_site_access.operate_policy_json, module.aboutme_lambda_access.operate_policy_json]
}
