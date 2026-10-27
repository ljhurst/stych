locals {
  aboutme = {
    api = [
      "arn:aws:apigateway:${local.region}::/restapis",
      "arn:aws:apigateway:${local.region}::/restapis/*",
      "arn:aws:apigateway:${local.region}::/tags/*",
    ]
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

data "aws_iam_policy_document" "aboutme_read" {
  source_policy_documents = [module.aboutme_site_access.read_policy_json, module.aboutme_lambda_access.read_policy_json]

  statement {
    sid       = "ReadApi"
    actions   = ["apigateway:GET"]
    resources = local.aboutme.api
  }
}

data "aws_iam_policy_document" "aboutme_write" {
  source_policy_documents = [module.aboutme_site_access.write_policy_json, module.aboutme_lambda_access.write_policy_json]

  statement {
    sid       = "ManageApi"
    actions   = ["apigateway:*"]
    resources = local.aboutme.api
  }
}

data "aws_iam_policy_document" "aboutme_operate" {
  source_policy_documents = [module.aboutme_site_access.operate_policy_json, module.aboutme_lambda_access.operate_policy_json]
}
