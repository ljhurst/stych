locals {
  fife = {
    policies = "arn:aws:iam::${local.account_id}:policy/fife-*"
    api = [
      "arn:aws:apigateway:${local.region}::/apis",
      "arn:aws:apigateway:${local.region}::/apis/*",
      "arn:aws:apigateway:${local.region}::/tags/*",
    ]
  }
}

module "fife_resource_groups" {
  source = "./modules/resource-group-access"

  project    = "fife"
  account_id = local.account_id
  region     = local.region
}

module "fife_lambda_access" {
  source = "./modules/lambda-access"

  project          = "fife"
  account_id       = local.account_id
  region           = local.region
  function_pattern = "fife-*"
}

module "fife_site_access" {
  source = "./modules/static-site-access"

  project         = "fife"
  bucket_name     = "lj-fife"
  account_id      = local.account_id
  certificate_arn = aws_acm_certificate.wildcard.arn
}

module "fife_dynamodb_access" {
  source = "./modules/dynamodb-access"

  account_id = local.account_id
  region     = local.region
  tables     = ["fife-*"]
}

module "fife" {
  source = "./modules/project-access"

  name                  = "fife"
  github_subject_prefix = "repo:ljhurst/fife"
  account_id            = local.account_id
  oidc_provider_arn     = aws_iam_openid_connect_provider.github.arn
  sso_instance_arn      = local.sso_instance_arn
  sso_user_id           = local.sso_user_id
  state_bucket_arn      = aws_s3_bucket.state.arn

  boundary_policy_json = data.aws_iam_policy_document.fife_boundary.json
  read_policy_json     = data.aws_iam_policy_document.fife_read.json
  write_policy_json    = data.aws_iam_policy_document.fife_write.json
  operate_policy_json  = data.aws_iam_policy_document.fife_operate.json
}

data "aws_iam_policy_document" "fife_boundary" {
  source_policy_documents = [module.fife_lambda_access.boundary_policy_json, module.fife_dynamodb_access.boundary_policy_json]
}

data "aws_iam_policy_document" "fife_read" {
  source_policy_documents = [module.fife_site_access.read_policy_json, module.fife_lambda_access.read_policy_json, module.fife_resource_groups.read_policy_json, module.fife_dynamodb_access.read_policy_json]

  statement {
    sid       = "ReadApi"
    actions   = ["apigateway:GET"]
    resources = local.fife.api
  }

  statement {
    sid       = "ReadPolicies"
    actions   = ["iam:GetPolicy", "iam:GetPolicyVersion", "iam:ListPolicyVersions", "iam:ListPolicyTags"]
    resources = [local.fife.policies]
  }
}

data "aws_iam_policy_document" "fife_write" {
  source_policy_documents = [module.fife_site_access.write_policy_json, module.fife_lambda_access.write_policy_json, module.fife_resource_groups.write_policy_json, module.fife_dynamodb_access.write_policy_json]

  statement {
    sid       = "ManageApi"
    actions   = ["apigateway:*"]
    resources = local.fife.api
  }

  statement {
    sid = "ManagePolicies"
    actions = [
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy",
    ]
    resources = [local.fife.policies]
  }
}

data "aws_iam_policy_document" "fife_operate" {
  source_policy_documents = [module.fife_site_access.operate_policy_json, module.fife_lambda_access.operate_policy_json, module.fife_dynamodb_access.operate_policy_json]
}
