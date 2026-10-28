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

output "dio_plan_role_arn" {
  description = "Role dio's PR plan jobs assume"
  value       = module.dio.plan_role_arn
}

output "dio_apply_role_arn" {
  description = "Role dio's apply job on main assumes"
  value       = module.dio.apply_role_arn
}

output "fife_plan_role_arn" {
  description = "Role fife's PR plan jobs assume"
  value       = module.fife.plan_role_arn
}

output "fife_apply_role_arn" {
  description = "Role fife's apply job on main assumes"
  value       = module.fife.apply_role_arn
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider that project CI roles trust"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "certificate_arn" {
  description = "Wildcard certificate every static site's CloudFront distribution uses"
  value       = aws_acm_certificate_validation.wildcard.certificate_arn
}

output "certificate_validation_records" {
  description = "DNS records that validate the wildcard certificate. Add them in Cloudflare as DNS only and keep them: ACM renews through them, and removing one breaks every site in about 13 months"
  value = distinct([
    for o in aws_acm_certificate.wildcard.domain_validation_options : {
      name  = o.resource_record_name
      type  = o.resource_record_type
      value = o.resource_record_value
    }
  ])
}

output "origin_verify_kvs_arn" {
  description = "Key value store holding each Function URL site's origin-verify secret, named by hostname"
  value       = aws_cloudfront_key_value_store.origin_verify.arn
}

output "aboutme_plan_role_arn" {
  description = "Role aboutme's PR plan jobs assume"
  value       = module.aboutme.plan_role_arn
}

output "aboutme_apply_role_arn" {
  description = "Role aboutme's apply job on main assumes"
  value       = module.aboutme.apply_role_arn
}

output "preview_certificate_validation_records" {
  description = "DNS records that validate the preview certificate. Add them in Cloudflare as DNS only and keep them: ACM renews through them"
  value       = module.site_previews.certificate_validation_records
}

output "preview_cname_target" {
  description = "Hostname the DNS-only wildcard record *.preview.bylukehurst.com points at"
  value       = module.site_previews.cname_target
}
