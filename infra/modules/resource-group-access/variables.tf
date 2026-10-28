variable "project" {
  description = "Project name; its resource groups are <project>-*"
  type        = string
}

variable "account_id" {
  description = "AWS account the project's resource groups live in"
  type        = string
}

variable "region" {
  description = "AWS region the project's resource groups live in"
  type        = string
}
