output "distribution_id" {
  description = "CloudFront distribution the deploy invalidates"
  value       = aws_cloudfront_distribution.this.id
}

output "cname_target" {
  description = "Hostname the site's DNS record points at"
  value       = aws_cloudfront_distribution.this.domain_name
}
