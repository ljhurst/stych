resource "aws_cloudfront_key_value_store" "origin_verify" {
  name    = "stych-origin-verify"
  comment = "Per-host secrets CloudFront presents to Function URL origins; scripts/set-origin-verify.sh writes them, Terraform never does"
}
