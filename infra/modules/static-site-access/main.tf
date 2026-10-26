locals {
  bucket = "arn:aws:s3:::${var.bucket_name}"
}

module "cloudfront" {
  source = "../cloudfront-access"

  project         = var.project
  account_id      = var.account_id
  certificate_arn = var.certificate_arn
}

# The site has no workload roles; the project-access module still requires a boundary.
data "aws_iam_policy_document" "boundary" {
  statement {
    sid       = "ReadSite"
    actions   = ["s3:GetObject"]
    resources = ["${local.bucket}/*"]
  }
}

data "aws_iam_policy_document" "read" {
  source_policy_documents = [module.cloudfront.read_policy_json]

  statement {
    sid       = "ReadSiteBucket"
    actions   = ["s3:ListBucket", "s3:GetBucket*", "s3:GetAccelerateConfiguration", "s3:GetLifecycleConfiguration", "s3:GetReplicationConfiguration", "s3:GetEncryptionConfiguration"]
    resources = [local.bucket]
  }

  statement {
    sid       = "ReadOriginAccessControl"
    actions   = ["cloudfront:GetOriginAccessControl"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "write" {
  source_policy_documents = [module.cloudfront.write_policy_json]

  statement {
    sid       = "ManageSiteBucket"
    actions   = ["s3:*"]
    resources = [local.bucket]
  }

  statement {
    sid       = "DeploySite"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.bucket}/*"]
  }

  statement {
    sid       = "InvalidateOwnDistribution"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = ["arn:aws:cloudfront::${var.account_id}:distribution/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project]
    }
  }

  # Origin access controls and response headers policies can't be tagged, so
  # they can only be scoped to the account.
  statement {
    sid       = "CreateDistributionParts"
    actions   = ["cloudfront:CreateOriginAccessControl", "cloudfront:CreateResponseHeadersPolicy"]
    resources = ["*"]
  }

  statement {
    sid = "ManageDistributionParts"
    actions = [
      "cloudfront:UpdateOriginAccessControl",
      "cloudfront:DeleteOriginAccessControl",
    ]
    resources = ["arn:aws:cloudfront::${var.account_id}:origin-access-control/*"]
  }

  statement {
    sid = "ManageResponseHeadersPolicies"
    actions = [
      "cloudfront:UpdateResponseHeadersPolicy",
      "cloudfront:DeleteResponseHeadersPolicy",
    ]
    resources = ["arn:aws:cloudfront::${var.account_id}:response-headers-policy/*"]
  }
}

data "aws_iam_policy_document" "operate" {
  statement {
    sid       = "ListSite"
    actions   = ["s3:ListBucket"]
    resources = [local.bucket]
  }

  statement {
    sid       = "ManageSiteObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.bucket}/*"]
  }
}
