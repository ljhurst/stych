variable "project" {
  description = "Project name; its CloudFront distributions must carry this as their Project tag"
  type        = string
}

variable "bucket_name" {
  description = "Bucket the project's site is deployed to"
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
