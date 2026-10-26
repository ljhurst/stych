locals {
  bracket_clash = {
    bucket = "arn:aws:s3:::lj-bracket-clash"
  }
}

module "bracket_clash" {
  source = "./modules/project-access"

  name                  = "bracket-clash"
  github_subject_prefix = "repo:ljhurst/bracket-clash"
  account_id            = local.account_id
  oidc_provider_arn     = aws_iam_openid_connect_provider.github.arn
  sso_instance_arn      = local.sso_instance_arn
  sso_user_id           = local.sso_user_id
  state_bucket_arn      = aws_s3_bucket.state.arn

  boundary_policy_json = data.aws_iam_policy_document.bracket_clash_boundary.json
  read_policy_json     = data.aws_iam_policy_document.bracket_clash_read.json
  write_policy_json    = data.aws_iam_policy_document.bracket_clash_write.json
  operate_policy_json  = data.aws_iam_policy_document.bracket_clash_operate.json
}

# The site has no workload roles; the module still requires a boundary.
data "aws_iam_policy_document" "bracket_clash_boundary" {
  statement {
    sid       = "ReadSite"
    actions   = ["s3:GetObject"]
    resources = ["${local.bracket_clash.bucket}/*"]
  }
}

data "aws_iam_policy_document" "bracket_clash_read" {
  statement {
    sid       = "ReadSiteBucket"
    actions   = ["s3:ListBucket", "s3:GetBucket*", "s3:GetAccelerateConfiguration", "s3:GetLifecycleConfiguration", "s3:GetReplicationConfiguration", "s3:GetEncryptionConfiguration"]
    resources = [local.bracket_clash.bucket]
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
    resources = [aws_acm_certificate.wildcard.arn]
  }
}

data "aws_iam_policy_document" "bracket_clash_write" {
  statement {
    sid       = "ManageSiteBucket"
    actions   = ["s3:*"]
    resources = [local.bracket_clash.bucket]
  }

  statement {
    sid       = "DeploySite"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.bracket_clash.bucket}/*"]
  }

  statement {
    sid       = "CreateDistribution"
    actions   = ["cloudfront:CreateDistribution", "cloudfront:TagResource"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = ["bracket-clash"]
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
    resources = ["arn:aws:cloudfront::${local.account_id}:distribution/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = ["bracket-clash"]
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
    resources = ["arn:aws:cloudfront::${local.account_id}:origin-access-control/*"]
  }

  statement {
    sid = "ManageResponseHeadersPolicies"
    actions = [
      "cloudfront:UpdateResponseHeadersPolicy",
      "cloudfront:DeleteResponseHeadersPolicy",
    ]
    resources = ["arn:aws:cloudfront::${local.account_id}:response-headers-policy/*"]
  }
}

data "aws_iam_policy_document" "bracket_clash_operate" {
  statement {
    sid       = "ListSite"
    actions   = ["s3:ListBucket"]
    resources = [local.bracket_clash.bucket]
  }

  statement {
    sid       = "ManageSiteObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.bracket_clash.bucket}/*"]
  }
}
