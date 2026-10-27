locals {
  functions = "arn:aws:cloudfront::${var.account_id}:function/${var.project}-*"
}

data "aws_iam_policy_document" "read" {
  statement {
    sid = "ReadDistribution"
    actions = [
      "cloudfront:GetDistribution",
      "cloudfront:GetCachePolicy",
      "cloudfront:ListCachePolicies",
      "cloudfront:GetOriginRequestPolicy",
      "cloudfront:ListOriginRequestPolicies",
      "cloudfront:GetResponseHeadersPolicy",
      "cloudfront:ListResponseHeadersPolicies",
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

  dynamic "statement" {
    for_each = var.origin_verify_kvs_arn == "" ? [] : [1]

    content {
      sid       = "ReadOriginVerify"
      actions   = ["cloudfront:DescribeFunction", "cloudfront:GetFunction"]
      resources = [local.functions]
    }
  }

  dynamic "statement" {
    for_each = var.origin_verify_kvs_arn == "" ? [] : [1]

    content {
      sid       = "UseOriginVerifyStore"
      actions   = ["cloudfront:DescribeKeyValueStore"]
      resources = [var.origin_verify_kvs_arn]
    }
  }
}

data "aws_iam_policy_document" "write" {
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
    ]
    resources = ["arn:aws:cloudfront::${var.account_id}:distribution/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project]
    }
  }

  dynamic "statement" {
    for_each = var.origin_verify_kvs_arn == "" ? [] : [1]

    content {
      sid = "ManageOriginVerifyFunctions"
      actions = [
        "cloudfront:CreateFunction",
        "cloudfront:UpdateFunction",
        "cloudfront:PublishFunction",
        "cloudfront:DeleteFunction",
      ]
      resources = [local.functions]
    }
  }
}
