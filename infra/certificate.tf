locals {
  domain = "bylukehurst.com"
}

resource "aws_acm_certificate" "wildcard" {
  domain_name               = "*.${local.domain}"
  subject_alternative_names = [local.domain]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn = aws_acm_certificate.wildcard.arn
}
