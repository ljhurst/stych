variable "name" {
  description = "Project name, used for the permission set (<name>-deploy), CI roles and policies"
  type        = string
}

variable "github_subject_prefix" {
  description = "The repo's OIDC subject prefix, as reported by GET /repos/{owner}/{repo}/actions/oidc/customization/sub"
  type        = string
}

variable "account_id" {
  description = "AWS account the permission set is assigned in"
  type        = string
}

variable "oidc_provider_arn" {
  description = "GitHub Actions OIDC provider the CI roles trust"
  type        = string
}

variable "sso_instance_arn" {
  description = "IAM Identity Center instance holding the permission set"
  type        = string
}

variable "sso_user_id" {
  description = "Identity Center user the permission set is assigned to"
  type        = string
}

variable "boundary_policy_json" {
  description = "Permissions boundary for the project's workload roles: the most any of them may do"
  type        = string
}

variable "state_bucket_arn" {
  description = "Bucket holding every project's Terraform state; the project gets only its own key"
  type        = string
}

variable "read_policy_json" {
  description = "Project-specific reads a Terraform plan needs; state and role reads are added by the module"
  type        = string
}

variable "write_policy_json" {
  description = "Project-specific writes a Terraform apply needs; state, boundary-gated IAM and boundary protection are added by the module"
  type        = string
}

variable "operate_policy_json" {
  description = "Local-only access beyond deploying, such as data and secrets"
  type        = string
}
