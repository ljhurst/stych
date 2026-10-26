locals {
  dio = {
    function    = "arn:aws:lambda:${local.region}:${local.account_id}:function:lj-dio-extract"
    vercel_oidc = "arn:aws:iam::${local.account_id}:oidc-provider/oidc.vercel.com/ljhursts-projects"
  }
}

module "dio_lambda_access" {
  source = "./modules/lambda-access"

  project          = "dio"
  account_id       = local.account_id
  region           = local.region
  function_pattern = "lj-dio-*"
  resource_groups  = false
}

module "dio" {
  source = "./modules/project-access"

  name                  = "dio"
  github_subject_prefix = "repo:ljhurst@9142868/dio@1315850400"
  account_id            = local.account_id
  oidc_provider_arn     = aws_iam_openid_connect_provider.github.arn
  sso_instance_arn      = local.sso_instance_arn
  sso_user_id           = local.sso_user_id
  state_bucket_arn      = aws_s3_bucket.state.arn

  boundary_policy_json = data.aws_iam_policy_document.dio_boundary.json
  read_policy_json     = data.aws_iam_policy_document.dio_read.json
  write_policy_json    = data.aws_iam_policy_document.dio_write.json
  operate_policy_json  = module.dio_lambda_access.operate_policy_json
}

data "aws_iam_policy_document" "dio_boundary" {
  source_policy_documents = [module.dio_lambda_access.boundary_policy_json]

  statement {
    sid       = "InvokeFunction"
    actions   = ["lambda:InvokeFunctionUrl", "lambda:InvokeFunction"]
    resources = [local.dio.function]
  }
}

data "aws_iam_policy_document" "dio_read" {
  source_policy_documents = [module.dio_lambda_access.read_policy_json]

  statement {
    sid       = "ReadVercelProvider"
    actions   = ["iam:GetOpenIDConnectProvider", "iam:ListOpenIDConnectProviderTags"]
    resources = [local.dio.vercel_oidc]
  }

}

data "aws_iam_policy_document" "dio_write" {
  source_policy_documents = [module.dio_lambda_access.write_policy_json]

  statement {
    sid = "ManageVercelProvider"
    actions = [
      "iam:AddClientIDToOpenIDConnectProvider",
      "iam:RemoveClientIDFromOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:TagOpenIDConnectProvider",
      "iam:UntagOpenIDConnectProvider",
    ]
    resources = [local.dio.vercel_oidc]
  }

}
