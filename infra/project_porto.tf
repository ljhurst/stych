locals {
  porto = {
    functions      = "arn:aws:lambda:${local.region}:${local.account_id}:function:lj-porto-mcp*"
    lwa_layer      = "arn:aws:lambda:${local.region}:753240598075:layer:LambdaAdapterLayerArm64:*"
    locks_table    = "arn:aws:dynamodb:${local.region}:${local.account_id}:table/porto-locks"
    log_group      = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/lj-porto-mcp*"
    roles          = "arn:aws:iam::${local.account_id}:role/porto-*"
    groups         = "arn:aws:resource-groups:${local.region}:${local.account_id}:group/porto-*"
    ssm_params     = "arn:aws:ssm:${local.region}:${local.account_id}:parameter/porto/*"
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
  statement {
    sid       = "ReadParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [local.porto.ssm_params]
  }

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

  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [local.porto.log_group, "${local.porto.log_group}:*"]
  }
}

data "aws_iam_policy_document" "porto_read" {
  source_policy_documents = [module.porto_cloudfront_access.read_policy_json]

  statement {
    sid       = "ReadFunctions"
    actions   = ["lambda:Get*", "lambda:List*"]
    resources = [local.porto.functions]
  }

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

  statement {
    sid       = "ListLogGroups"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  statement {
    sid       = "ReadLogGroup"
    actions   = ["logs:ListTagsForResource", "logs:ListTagsLogGroup"]
    resources = [local.porto.log_group, "${local.porto.log_group}:*"]
  }

  statement {
    sid       = "ReadResourceGroups"
    actions   = ["resource-groups:Get*", "resource-groups:List*"]
    resources = [local.porto.groups]
  }
}

data "aws_iam_policy_document" "porto_write" {
  source_policy_documents = [module.porto_cloudfront_access.write_policy_json]

  statement {
    sid       = "ManageFunctions"
    actions   = ["lambda:*"]
    resources = [local.porto.functions]
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
    resources = [local.porto.locks_table]
  }

  statement {
    sid       = "ManageLogGroup"
    actions   = ["logs:*"]
    resources = [local.porto.log_group, "${local.porto.log_group}:*"]
  }

  statement {
    sid       = "ManageResourceGroups"
    actions   = ["resource-groups:*"]
    resources = [local.porto.groups]
  }

  statement {
    sid       = "PassRolesToLambda"
    actions   = ["iam:PassRole"]
    resources = [local.porto.roles]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "porto_operate" {
  statement {
    sid       = "LockTableData"
    actions   = concat(local.porto.table_data_ops, ["dynamodb:DescribeTable"])
    resources = [local.porto.locks_table]
  }

  statement {
    sid       = "ManageParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:PutParameter", "ssm:GetParameterHistory"]
    resources = [local.porto.ssm_params]
  }

  statement {
    sid       = "ReadLogs"
    actions   = ["logs:FilterLogEvents", "logs:GetLogEvents", "logs:DescribeLogStreams", "logs:StartQuery", "logs:StopQuery"]
    resources = [local.porto.log_group, "${local.porto.log_group}:*"]
  }

  statement {
    sid       = "QueryResults"
    actions   = ["logs:GetQueryResults", "logs:DescribeQueries"]
    resources = ["*"]
  }
}
