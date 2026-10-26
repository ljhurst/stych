locals {
  lasso = {
    lwa_layer      = "arn:aws:lambda:${local.region}:753240598075:layer:LambdaAdapterLayerArm64:*"
    tables         = "arn:aws:dynamodb:${local.region}:${local.account_id}:table/lj-lasso*"
    table_data_ops = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:BatchGetItem", "dynamodb:BatchWriteItem", "dynamodb:ConditionCheckItem"]
  }
}

module "lasso_lambda_access" {
  source = "./modules/lambda-access"

  project          = "lasso"
  account_id       = local.account_id
  region           = local.region
  function_pattern = "lj-lasso*"
}

module "lasso" {
  source = "./modules/project-access"

  name                  = "lasso"
  github_subject_prefix = "repo:ljhurst@9142868/lasso@1341558720"
  account_id            = local.account_id
  oidc_provider_arn     = aws_iam_openid_connect_provider.github.arn
  sso_instance_arn      = local.sso_instance_arn
  sso_user_id           = local.sso_user_id
  state_bucket_arn      = aws_s3_bucket.state.arn

  boundary_policy_json = data.aws_iam_policy_document.lasso_boundary.json
  read_policy_json     = data.aws_iam_policy_document.lasso_read.json
  write_policy_json    = data.aws_iam_policy_document.lasso_write.json
  operate_policy_json  = data.aws_iam_policy_document.lasso_operate.json
}

data "aws_iam_policy_document" "lasso_boundary" {
  source_policy_documents = [module.lasso_lambda_access.boundary_policy_json]

  statement {
    sid       = "TableData"
    actions   = local.lasso.table_data_ops
    resources = [local.lasso.tables, "${local.lasso.tables}/index/*"]
  }

}

data "aws_iam_policy_document" "lasso_read" {
  source_policy_documents = [module.lasso_lambda_access.read_policy_json]

  statement {
    sid       = "ReadAdapterLayer"
    actions   = ["lambda:GetLayerVersion"]
    resources = [local.lasso.lwa_layer]
  }

  statement {
    sid       = "ReadTables"
    actions   = ["dynamodb:Describe*", "dynamodb:ListTagsOfResource", "dynamodb:GetResourcePolicy"]
    resources = [local.lasso.tables]
  }

}

data "aws_iam_policy_document" "lasso_write" {
  source_policy_documents = [module.lasso_lambda_access.write_policy_json]

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
    resources = [local.lasso.tables]
  }

}

data "aws_iam_policy_document" "lasso_operate" {
  source_policy_documents = [module.lasso_lambda_access.operate_policy_json]

  statement {
    sid       = "TableData"
    actions   = concat(local.lasso.table_data_ops, ["dynamodb:DescribeTable"])
    resources = [local.lasso.tables, "${local.lasso.tables}/index/*"]
  }

}
