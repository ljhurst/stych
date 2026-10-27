locals {
  parent_domain = regex("^[^.]+\\.(.+)$", var.domain_name)[0]
  origin_domain = regex("^https://([^/]+)/?$", var.function_url)[0]
}

data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

data "aws_cloudfront_response_headers_policy" "security" {
  name = "Managed-SecurityHeadersPolicy"
}

data "aws_acm_certificate" "this" {
  domain      = "*.${local.parent_domain}"
  statuses    = ["ISSUED"]
  most_recent = true
}

resource "aws_cloudfront_function" "origin_verify" {
  count = var.origin_verify_kvs_arn == "" ? 0 : 1

  name                         = "${split(".", var.domain_name)[0]}-origin-verify"
  runtime                      = "cloudfront-js-2.0"
  publish                      = true
  code                         = file("${path.module}/origin-verify.js")
  key_value_store_associations = [var.origin_verify_kvs_arn]
}

resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  is_ipv6_enabled = true
  http_version    = "http2and3"
  price_class     = "PriceClass_100"
  aliases         = [var.domain_name]

  origin {
    domain_name = local.origin_domain
    origin_id   = "function-url"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
      origin_read_timeout    = var.origin_timeout
    }

    # The Host header is the Function URL's, so services behind a trusting proxy read the public host here.
    custom_header {
      name  = "X-Forwarded-Host"
      value = var.domain_name
    }
  }

  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "function-url"
    viewer_protocol_policy     = "redirect-to-https"
    cache_policy_id            = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security.id

    dynamic "function_association" {
      for_each = aws_cloudfront_function.origin_verify

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
