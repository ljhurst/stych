variable "project" {
  description = "Project name; its roles are <project>-*, its parameters /<project>/* and its resource groups <project>-*"
  type        = string
}

variable "account_id" {
  description = "AWS account the project's resources live in"
  type        = string
}

variable "region" {
  description = "AWS region the project's resources live in"
  type        = string
}

variable "function_pattern" {
  description = "Name pattern of the project's Lambda functions, e.g. lj-dio-*; their log groups are /aws/lambda/<pattern>"
  type        = string
}

variable "resource_groups" {
  description = "Whether the project has resource groups to read and manage"
  type        = bool
  default     = true
}
