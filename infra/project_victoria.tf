locals {
  victoria = {
    functions   = "arn:aws:lambda:${local.region}:${local.account_id}:function:lj-victoria-*"
    log_group   = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/lj-victoria-*"
    roles       = "arn:aws:iam::${local.account_id}:role/victoria-*"
    groups      = "arn:aws:resource-groups:${local.region}:${local.account_id}:group/victoria-*"
    ssm_params  = "arn:aws:ssm:${local.region}:${local.account_id}:parameter/victoria/*"
    wiki_bucket = "arn:aws:s3:::lj-victoria-wiki"

    # Only the seed pages Terraform manages; CI never reads the rest of the wiki.
    managed_pages = [
      "arn:aws:s3:::lj-victoria-wiki/CONVENTIONS.md",
      "arn:aws:s3:::lj-victoria-wiki/index.md",
      "arn:aws:s3:::lj-victoria-wiki/log.md",
    ]
  }
}

module "victoria" {
  source = "./modules/project-access"

  name                  = "victoria"
  github_subject_prefix = "repo:ljhurst@9142868/victoria@1336851147"
  account_id            = local.account_id
  oidc_provider_arn     = aws_iam_openid_connect_provider.github.arn
  sso_instance_arn      = local.sso_instance_arn
  sso_user_id           = local.sso_user_id
  state_bucket_arn      = aws_s3_bucket.state.arn

  boundary_policy_json = data.aws_iam_policy_document.victoria_boundary.json
  read_policy_json     = data.aws_iam_policy_document.victoria_read.json
  write_policy_json    = data.aws_iam_policy_document.victoria_write.json
  operate_policy_json  = data.aws_iam_policy_document.victoria_operate.json
}

data "aws_iam_policy_document" "victoria_boundary" {
  statement {
    sid       = "ListWiki"
    actions   = ["s3:ListBucket"]
    resources = [local.victoria.wiki_bucket]
  }

  statement {
    sid       = "ReadWriteWiki"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${local.victoria.wiki_bucket}/*"]
  }

  statement {
    sid       = "ReadParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [local.victoria.ssm_params]
  }

  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [local.victoria.log_group, "${local.victoria.log_group}:*"]
  }
}

data "aws_iam_policy_document" "victoria_read" {
  statement {
    sid       = "ReadFunctions"
    actions   = ["lambda:Get*", "lambda:List*"]
    resources = [local.victoria.functions]
  }

  statement {
    sid       = "ReadWikiBucket"
    actions   = ["s3:ListBucket", "s3:GetBucket*", "s3:GetAccelerateConfiguration", "s3:GetLifecycleConfiguration", "s3:GetReplicationConfiguration", "s3:GetEncryptionConfiguration"]
    resources = [local.victoria.wiki_bucket]
  }

  statement {
    sid       = "ReadManagedPages"
    actions   = ["s3:GetObject", "s3:GetObjectTagging", "s3:GetObjectAcl"]
    resources = local.victoria.managed_pages
  }

  statement {
    sid       = "ListLogGroups"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  statement {
    sid       = "ReadLogGroups"
    actions   = ["logs:ListTagsForResource", "logs:ListTagsLogGroup"]
    resources = [local.victoria.log_group, "${local.victoria.log_group}:*"]
  }

  statement {
    sid       = "ReadResourceGroups"
    actions   = ["resource-groups:Get*", "resource-groups:List*"]
    resources = [local.victoria.groups]
  }
}

data "aws_iam_policy_document" "victoria_write" {
  statement {
    sid       = "ManageFunctions"
    actions   = ["lambda:*"]
    resources = [local.victoria.functions]
  }

  statement {
    sid       = "ManageWikiBucket"
    actions   = ["s3:*"]
    resources = [local.victoria.wiki_bucket]
  }

  statement {
    sid       = "ManageManagedPages"
    actions   = ["s3:PutObject", "s3:DeleteObject", "s3:PutObjectTagging"]
    resources = local.victoria.managed_pages
  }

  statement {
    sid       = "ManageLogGroups"
    actions   = ["logs:*"]
    resources = [local.victoria.log_group, "${local.victoria.log_group}:*"]
  }

  statement {
    sid       = "ManageResourceGroups"
    actions   = ["resource-groups:*"]
    resources = [local.victoria.groups]
  }

  statement {
    sid       = "PassRolesToLambda"
    actions   = ["iam:PassRole"]
    resources = [local.victoria.roles]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "victoria_operate" {
  statement {
    sid       = "ListWiki"
    actions   = ["s3:ListBucket"]
    resources = [local.victoria.wiki_bucket]
  }

  statement {
    sid       = "ManageWikiPages"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.victoria.wiki_bucket}/*"]
  }

  statement {
    sid       = "ManageParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:PutParameter", "ssm:GetParameterHistory"]
    resources = [local.victoria.ssm_params]
  }

  statement {
    sid       = "ReadLogs"
    actions   = ["logs:FilterLogEvents", "logs:GetLogEvents", "logs:DescribeLogStreams", "logs:StartQuery", "logs:StopQuery"]
    resources = [local.victoria.log_group, "${local.victoria.log_group}:*"]
  }

  statement {
    sid       = "QueryResults"
    actions   = ["logs:GetQueryResults", "logs:DescribeQueries"]
    resources = ["*"]
  }
}
