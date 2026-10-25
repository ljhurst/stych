locals {
  train_spotting = {
    bucket = "arn:aws:s3:::lj-train-spotting"
  }
}

module "train_spotting" {
  source = "./modules/project-access"

  name                  = "train-spotting"
  github_subject_prefix = "repo:ljhurst/train-spotting"
  account_id            = local.account_id
  oidc_provider_arn     = aws_iam_openid_connect_provider.github.arn
  sso_instance_arn      = local.sso_instance_arn
  sso_user_id           = local.sso_user_id
  state_bucket_arn      = aws_s3_bucket.state.arn

  boundary_policy_json = data.aws_iam_policy_document.train_spotting_boundary.json
  read_policy_json     = data.aws_iam_policy_document.train_spotting_read.json
  write_policy_json    = data.aws_iam_policy_document.train_spotting_write.json
  operate_policy_json  = data.aws_iam_policy_document.train_spotting_operate.json
}

# The site has no workload roles; the module still requires a boundary.
data "aws_iam_policy_document" "train_spotting_boundary" {
  statement {
    sid       = "ReadSite"
    actions   = ["s3:GetObject"]
    resources = ["${local.train_spotting.bucket}/*"]
  }
}

data "aws_iam_policy_document" "train_spotting_read" {
  statement {
    sid       = "ReadSiteBucket"
    actions   = ["s3:ListBucket", "s3:GetBucket*", "s3:GetAccelerateConfiguration", "s3:GetLifecycleConfiguration", "s3:GetReplicationConfiguration", "s3:GetEncryptionConfiguration"]
    resources = [local.train_spotting.bucket]
  }
}

data "aws_iam_policy_document" "train_spotting_write" {
  statement {
    sid       = "ManageSiteBucket"
    actions   = ["s3:*"]
    resources = [local.train_spotting.bucket]
  }

  statement {
    sid       = "DeploySite"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.train_spotting.bucket}/*"]
  }
}

data "aws_iam_policy_document" "train_spotting_operate" {
  statement {
    sid       = "ListSite"
    actions   = ["s3:ListBucket"]
    resources = [local.train_spotting.bucket]
  }

  statement {
    sid       = "ManageSiteObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.train_spotting.bucket}/*"]
  }
}
