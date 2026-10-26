module "bracket_clash_access" {
  source = "./modules/static-site-access"

  project         = "bracket-clash"
  bucket_name     = "lj-bracket-clash"
  account_id      = local.account_id
  certificate_arn = aws_acm_certificate.wildcard.arn
}

module "bracket_clash" {
  source = "./modules/project-access"

  name                  = "bracket-clash"
  github_subject_prefix = "repo:ljhurst/bracket-clash"
  account_id            = local.account_id
  oidc_provider_arn     = aws_iam_openid_connect_provider.github.arn
  sso_instance_arn      = local.sso_instance_arn
  sso_user_id           = local.sso_user_id
  state_bucket_arn      = aws_s3_bucket.state.arn

  boundary_policy_json = module.bracket_clash_access.boundary_policy_json
  read_policy_json     = module.bracket_clash_access.read_policy_json
  write_policy_json    = module.bracket_clash_access.write_policy_json
  operate_policy_json  = module.bracket_clash_access.operate_policy_json
}
