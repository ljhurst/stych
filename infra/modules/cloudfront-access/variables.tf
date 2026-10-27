variable "project" {
  description = "Project name; its CloudFront distributions must carry this as their Project tag"
  type        = string
}

variable "account_id" {
  description = "AWS account the project's CloudFront resources live in"
  type        = string
}

variable "certificate_arn" {
  description = "Wildcard certificate the project's distributions use"
  type        = string
}

variable "origin_verify_kvs_arn" {
  description = "Key value store holding the origin-verify secrets; set it for a project whose sites use origin verification, which lets its roles manage the project's <project>-* functions"
  type        = string
  default     = ""
}
