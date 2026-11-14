locals {
  freal = {
    espn_params = "arn:aws:ssm:${local.region}:${local.account_id}:parameter/freal/espn/*"
  }
}

module "freal_access" {
  source = "./modules/static-site-access"

  project         = "freal"
  bucket_name     = "lj-freal"
  account_id      = local.account_id
  certificate_arn = aws_acm_certificate.wildcard.arn

  previews = module.site_previews.access
}

module "freal_lambda_access" {
  source = "./modules/lambda-access"

  project          = "freal"
  account_id       = local.account_id
  region           = local.region
  function_pattern = "lj-freal-*"

  writable_parameters = ["espn/*"]
}

module "freal_resource_groups" {
  source = "./modules/resource-group-access"

  project    = "freal"
  account_id = local.account_id
  region     = local.region
}

module "freal" {
  source = "./modules/project-access"

  name                  = "freal"
  github_subject_prefix = "repo:ljhurst@9142868/freal@1458148914"
  account_id            = local.account_id
  oidc_provider_arn     = aws_iam_openid_connect_provider.github.arn
  sso_instance_arn      = local.sso_instance_arn
  sso_user_id           = local.sso_user_id
  state_bucket_arn      = aws_s3_bucket.state.arn

  boundary_policy_json = data.aws_iam_policy_document.freal_boundary.json
  read_policy_json     = data.aws_iam_policy_document.freal_read.json
  write_policy_json    = data.aws_iam_policy_document.freal_write.json
  operate_policy_json  = data.aws_iam_policy_document.freal_operate.json
  plan_policy_jsons    = { preview = module.freal_access.preview_policy_json }
}

data "aws_iam_policy_document" "freal_boundary" {
  source_policy_documents = [module.freal_access.boundary_policy_json, module.freal_lambda_access.boundary_policy_json]

  statement {
    sid       = "WriteEspnCredentials"
    actions   = ["ssm:PutParameter"]
    resources = [local.freal.espn_params]
  }
}

data "aws_iam_policy_document" "freal_read" {
  source_policy_documents = [module.freal_access.read_policy_json, module.freal_lambda_access.read_policy_json, module.freal_resource_groups.read_policy_json]
}

data "aws_iam_policy_document" "freal_write" {
  source_policy_documents = [module.freal_access.write_policy_json, module.freal_lambda_access.write_policy_json, module.freal_resource_groups.write_policy_json]
}

data "aws_iam_policy_document" "freal_operate" {
  source_policy_documents = [module.freal_access.operate_policy_json, module.freal_lambda_access.operate_policy_json]
}
