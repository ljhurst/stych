variable "name" {
  description = "Project name, used for the permission set (<name>-deploy), CI roles and policies"
  type        = string
}

variable "repo" {
  description = "GitHub repository whose workflows may assume the CI roles, as owner/name"
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

variable "read_policy_json" {
  description = "What a Terraform plan needs: read the project's resources and its state"
  type        = string
}

variable "write_policy_json" {
  description = "What a Terraform apply needs beyond read"
  type        = string
}

variable "operate_policy_json" {
  description = "Local-only access beyond deploying, such as data and secrets"
  type        = string
}
