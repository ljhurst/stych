locals {
  victoria = {
    wiki_bucket = "arn:aws:s3:::lj-victoria-wiki"

    # Only the seed pages Terraform manages; CI never reads the rest of the wiki.
    managed_pages = [
      "arn:aws:s3:::lj-victoria-wiki/CONVENTIONS.md",
      "arn:aws:s3:::lj-victoria-wiki/index.md",
      "arn:aws:s3:::lj-victoria-wiki/log.md",
    ]
  }
}

module "victoria_cloudfront_access" {
  source = "./modules/cloudfront-access"

  project         = "victoria"
  account_id      = local.account_id
  certificate_arn = aws_acm_certificate.wildcard.arn
}

module "victoria_lambda_access" {
  source = "./modules/lambda-access"

  project          = "victoria"
  account_id       = local.account_id
  region           = local.region
  function_pattern = "lj-victoria-*"
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
  source_policy_documents = [module.victoria_lambda_access.boundary_policy_json]

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

}

data "aws_iam_policy_document" "victoria_read" {
  source_policy_documents = [module.victoria_cloudfront_access.read_policy_json, module.victoria_lambda_access.read_policy_json]

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

}

data "aws_iam_policy_document" "victoria_write" {
  source_policy_documents = [module.victoria_cloudfront_access.write_policy_json, module.victoria_lambda_access.write_policy_json]

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

}

data "aws_iam_policy_document" "victoria_operate" {
  source_policy_documents = [module.victoria_lambda_access.operate_policy_json]

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

}
