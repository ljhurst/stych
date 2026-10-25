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

output "porto_plan_role_arn" {
  description = "Role Porto's PR plan jobs assume"
  value       = module.porto.plan_role_arn
}

output "porto_apply_role_arn" {
  description = "Role Porto's apply job on main assumes"
  value       = module.porto.apply_role_arn
}

output "victoria_plan_role_arn" {
  description = "Role Victoria's PR plan jobs assume"
  value       = module.victoria.plan_role_arn
}

output "victoria_apply_role_arn" {
  description = "Role Victoria's apply job on main assumes"
  value       = module.victoria.apply_role_arn
}

output "train_spotting_plan_role_arn" {
  description = "Role train-spotting's PR plan and site preview jobs assume"
  value       = module.train_spotting.plan_role_arn
}

output "train_spotting_apply_role_arn" {
  description = "Role train-spotting's apply and site deploy jobs assume"
  value       = module.train_spotting.apply_role_arn
}

output "bracket_clash_plan_role_arn" {
  description = "Role bracket-clash's PR plan and site preview jobs assume"
  value       = module.bracket_clash.plan_role_arn
}

output "bracket_clash_apply_role_arn" {
  description = "Role bracket-clash's apply and site deploy jobs assume"
  value       = module.bracket_clash.apply_role_arn
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider that project CI roles trust"
  value       = aws_iam_openid_connect_provider.github.arn
}
