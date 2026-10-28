output "access" {
  description = "What a project's plan role needs to deploy previews, for the previews input of static-site-access"
  value = {
    bucket  = var.bucket_name
    kvs_arn = aws_cloudfront_key_value_store.this.arn
  }
}

output "cname_target" {
  description = "Hostname the wildcard DNS record *.<domain_name> points at"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "certificate_validation_records" {
  description = "DNS records that validate the preview certificate. Add them in Cloudflare as DNS only and keep them: ACM renews through them"
  value = distinct([
    for o in aws_acm_certificate.this.domain_validation_options : {
      name  = o.resource_record_name
      type  = o.resource_record_type
      value = o.resource_record_value
    }
  ])
}
