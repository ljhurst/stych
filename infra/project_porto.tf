locals {
  porto = {
    lwa_layer      = "arn:aws:lambda:${local.region}:753240598075:layer:LambdaAdapterLayerArm64:*"
    locks_table    = "arn:aws:dynamodb:${local.region}:${local.account_id}:table/porto-locks"
    session_param  = "arn:aws:ssm:${local.region}:${local.account_id}:parameter/porto/sommething/session"
    table_data_ops = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:ConditionCheckItem"]
  }
}

module "porto_cloudfront_access" {
  source = "./modules/cloudfront-access"

  project         = "porto"
  account_id      = local.account_id
  certificate_arn = aws_acm_certificate.wildcard.arn
}

module "porto_lambda_access" {
  source = "./modules/lambda-access"

  project          = "porto"
  account_id       = local.account_id
  region           = local.region
  function_pattern = "lj-porto-mcp*"
}

module "porto" {
  source = "./modules/project-access"

  name                  = "porto"
  github_subject_prefix = "repo:ljhurst@9142868/porto@1336875812"
  account_id            = local.account_id
  oidc_provider_arn     = aws_iam_openid_connect_provider.github.arn
  sso_instance_arn      = local.sso_instance_arn
  sso_user_id           = local.sso_user_id
  state_bucket_arn      = aws_s3_bucket.state.arn

  boundary_policy_json = data.aws_iam_policy_document.porto_boundary.json
  read_policy_json     = data.aws_iam_policy_document.porto_read.json
  write_policy_json    = data.aws_iam_policy_document.porto_write.json
  operate_policy_json  = data.aws_iam_policy_document.porto_operate.json
}

data "aws_iam_policy_document" "porto_boundary" {
  source_policy_documents = [module.porto_lambda_access.boundary_policy_json]

  statement {
    sid       = "RotateSession"
    actions   = ["ssm:PutParameter"]
    resources = [local.porto.session_param]
  }

  statement {
    sid       = "TokenRefreshLock"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem"]
    resources = [local.porto.locks_table]
  }

}

data "aws_iam_policy_document" "porto_read" {
  source_policy_documents = [module.porto_cloudfront_access.read_policy_json, module.porto_lambda_access.read_policy_json]

  statement {
    sid       = "ReadAdapterLayer"
    actions   = ["lambda:GetLayerVersion"]
    resources = [local.porto.lwa_layer]
  }

  statement {
    sid       = "ReadTables"
    actions   = ["dynamodb:Describe*", "dynamodb:ListTagsOfResource", "dynamodb:GetResourcePolicy"]
    resources = [local.porto.locks_table]
  }

}

data "aws_iam_policy_document" "porto_write" {
  source_policy_documents = [module.porto_cloudfront_access.write_policy_json, module.porto_lambda_access.write_policy_json]

  statement {
    sid = "ManageTables"
    actions = [
      "dynamodb:CreateTable",
      "dynamodb:UpdateTable",
      "dynamodb:DeleteTable",
      "dynamodb:TagResource",
      "dynamodb:UntagResource",
      "dynamodb:UpdateTimeToLive",
      "dynamodb:UpdateContinuousBackups",
      "dynamodb:PutResourcePolicy",
      "dynamodb:DeleteResourcePolicy",
    ]
    resources = [local.porto.locks_table]
  }

}

data "aws_iam_policy_document" "porto_operate" {
  source_policy_documents = [module.porto_lambda_access.operate_policy_json]

  statement {
    sid       = "LockTableData"
    actions   = concat(local.porto.table_data_ops, ["dynamodb:DescribeTable"])
    resources = [local.porto.locks_table]
  }

}
