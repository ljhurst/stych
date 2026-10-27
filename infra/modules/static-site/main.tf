locals {
  parent_domain = regex("^[^.]+\\.(.+)$", var.domain_name)[0]
}

data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_acm_certificate" "this" {
  domain      = "*.${local.parent_domain}"
  statuses    = ["ISSUED"]
  most_recent = true
}

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket.json

  depends_on = [aws_s3_bucket_public_access_block.this]
}

data "aws_iam_policy_document" "bucket" {
  statement {
    sid       = "ReadFromCloudFront"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = var.bucket_name
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_response_headers_policy" "this" {
  name = var.bucket_name

  security_headers_config {
    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = false
      preload                    = false
      override                   = true
    }

    content_security_policy {
      content_security_policy = var.content_security_policy
      override                = true
    }
  }
}

resource "aws_cloudfront_function" "directory_index" {
  count = var.directory_index ? 1 : 0

  name    = "${var.bucket_name}-directory-index"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = file("${path.module}/directory-index.js")
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  price_class         = "PriceClass_100"
  aliases             = [var.domain_name]
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.this.bucket_regional_domain_name
    origin_id                = "s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "s3"
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.this.id

    dynamic "function_association" {
      for_each = aws_cloudfront_function.directory_index

      content {
        event_type   = "viewer-request"
        function_arn = function_association.value.arn
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.this.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
