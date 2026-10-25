output "state_bucket" {
  description = "Bucket holding every project's Terraform state"
  value       = aws_s3_bucket.state.id
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider that project CI roles trust"
  value       = aws_iam_openid_connect_provider.github.arn
}
