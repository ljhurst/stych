output "distribution_id" {
  description = "CloudFront distribution in front of the function"
  value       = aws_cloudfront_distribution.this.id
}

output "cname_target" {
  description = "Hostname the service's DNS record points at (DNS only in Cloudflare)"
  value       = aws_cloudfront_distribution.this.domain_name
}
