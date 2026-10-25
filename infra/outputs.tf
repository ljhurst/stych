output "state_bucket" {
  description = "Bucket holding every project's Terraform state"
  value       = aws_s3_bucket.state.id
}

output "lasso_plan_role_arn" {
  description = "Role Lasso's PR plan jobs assume"
  value       = module.lasso.plan_role_arn
}

output "lasso_apply_role_arn" {
  description = "Role Lasso's apply job on main assumes"
  value       = module.lasso.apply_role_arn
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider that project CI roles trust"
  value       = aws_iam_openid_connect_provider.github.arn
}
