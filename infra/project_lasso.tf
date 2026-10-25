locals {
  lasso = {
    functions      = "arn:aws:lambda:${local.region}:${local.account_id}:function:lj-lasso*"
    lwa_layer      = "arn:aws:lambda:${local.region}:753240598075:layer:LambdaAdapterLayerArm64:*"
    tables         = "arn:aws:dynamodb:${local.region}:${local.account_id}:table/lj-lasso*"
    log_group      = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/lj-lasso*"
    roles          = "arn:aws:iam::${local.account_id}:role/lasso-*"
    groups         = "arn:aws:resource-groups:${local.region}:${local.account_id}:group/lasso-*"
    ssm_params     = "arn:aws:ssm:${local.region}:${local.account_id}:parameter/lasso/*"
    table_data_ops = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:BatchGetItem", "dynamodb:BatchWriteItem", "dynamodb:ConditionCheckItem"]
  }
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
  statement {
    sid       = "TableData"
    actions   = local.lasso.table_data_ops
    resources = [local.lasso.tables, "${local.lasso.tables}/index/*"]
  }

  statement {
    sid       = "ReadParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [local.lasso.ssm_params]
  }

  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [local.lasso.log_group, "${local.lasso.log_group}:*"]
  }
}

data "aws_iam_policy_document" "lasso_read" {
  statement {
    sid       = "ReadFunctions"
    actions   = ["lambda:Get*", "lambda:List*"]
    resources = [local.lasso.functions]
  }

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

  statement {
    sid       = "ListLogGroups"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  statement {
    sid       = "ReadLogGroup"
    actions   = ["logs:ListTagsForResource", "logs:ListTagsLogGroup"]
    resources = [local.lasso.log_group, "${local.lasso.log_group}:*"]
  }

  statement {
    sid       = "ReadResourceGroups"
    actions   = ["resource-groups:Get*", "resource-groups:List*"]
    resources = [local.lasso.groups]
  }
}

data "aws_iam_policy_document" "lasso_write" {
  statement {
    sid       = "ManageFunctions"
    actions   = ["lambda:*"]
    resources = [local.lasso.functions]
  }

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

  statement {
    sid       = "ManageLogGroup"
    actions   = ["logs:*"]
    resources = [local.lasso.log_group, "${local.lasso.log_group}:*"]
  }

  statement {
    sid       = "ManageResourceGroups"
    actions   = ["resource-groups:*"]
    resources = [local.lasso.groups]
  }

  statement {
    sid       = "PassRolesToLambda"
    actions   = ["iam:PassRole"]
    resources = [local.lasso.roles]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lasso_operate" {
  statement {
    sid       = "TableData"
    actions   = concat(local.lasso.table_data_ops, ["dynamodb:DescribeTable"])
    resources = [local.lasso.tables, "${local.lasso.tables}/index/*"]
  }

  statement {
    sid       = "ManageParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:PutParameter", "ssm:GetParameterHistory"]
    resources = [local.lasso.ssm_params]
  }

  statement {
    sid       = "ReadLogs"
    actions   = ["logs:FilterLogEvents", "logs:GetLogEvents", "logs:DescribeLogStreams", "logs:StartQuery", "logs:StopQuery"]
    resources = [local.lasso.log_group, "${local.lasso.log_group}:*"]
  }

  statement {
    sid       = "QueryResults"
    actions   = ["logs:GetQueryResults", "logs:DescribeQueries"]
    resources = ["*"]
  }
}
