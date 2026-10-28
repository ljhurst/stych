module "train_spotting_access" {
  source = "./modules/static-site-access"

  project         = "train-spotting"
  bucket_name     = "lj-train-spotting"
  account_id      = local.account_id
  certificate_arn = aws_acm_certificate.wildcard.arn
}

module "train_spotting_resource_groups" {
  source = "./modules/resource-group-access"

  project    = "train-spotting"
  account_id = local.account_id
  region     = local.region
}

module "train_spotting" {
  source = "./modules/project-access"

  name                  = "train-spotting"
  github_subject_prefix = "repo:ljhurst/train-spotting"
  account_id            = local.account_id
  oidc_provider_arn     = aws_iam_openid_connect_provider.github.arn
  sso_instance_arn      = local.sso_instance_arn
  sso_user_id           = local.sso_user_id
  state_bucket_arn      = aws_s3_bucket.state.arn

  boundary_policy_json = module.train_spotting_access.boundary_policy_json
  read_policy_json     = data.aws_iam_policy_document.train_spotting_read.json
  write_policy_json    = data.aws_iam_policy_document.train_spotting_write.json
  operate_policy_json  = module.train_spotting_access.operate_policy_json
}

data "aws_iam_policy_document" "train_spotting_read" {
  source_policy_documents = [module.train_spotting_access.read_policy_json, module.train_spotting_resource_groups.read_policy_json]
}

data "aws_iam_policy_document" "train_spotting_write" {
  source_policy_documents = [module.train_spotting_access.write_policy_json, module.train_spotting_resource_groups.write_policy_json]
}
