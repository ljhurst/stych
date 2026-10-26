locals {
  bucket = "arn:aws:s3:::${var.bucket_name}"
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
  statement {
    sid       = "ReadSiteBucket"
    actions   = ["s3:ListBucket", "s3:GetBucket*", "s3:GetAccelerateConfiguration", "s3:GetLifecycleConfiguration", "s3:GetReplicationConfiguration", "s3:GetEncryptionConfiguration"]
    resources = [local.bucket]
  }

  statement {
    sid = "ReadDistribution"
    actions = [
      "cloudfront:GetDistribution",
      "cloudfront:GetOriginAccessControl",
      "cloudfront:GetResponseHeadersPolicy",
      "cloudfront:GetCachePolicy",
      "cloudfront:ListCachePolicies",
      "cloudfront:ListTagsForResource",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "FindCertificate"
    actions   = ["acm:ListCertificates"]
    resources = ["*"]
  }

  statement {
    sid       = "ReadCertificate"
    actions   = ["acm:DescribeCertificate", "acm:GetCertificate", "acm:ListTagsForCertificate"]
    resources = [var.certificate_arn]
  }
}

data "aws_iam_policy_document" "write" {
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
    sid       = "CreateDistribution"
    actions   = ["cloudfront:CreateDistribution", "cloudfront:TagResource"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = [var.project]
    }
  }

  statement {
    sid = "ManageOwnDistribution"
    actions = [
      "cloudfront:UpdateDistribution",
      "cloudfront:DeleteDistribution",
      "cloudfront:UntagResource",
      "cloudfront:CreateInvalidation",
    ]
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
