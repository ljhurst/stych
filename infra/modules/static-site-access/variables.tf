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

variable "previews" {
  description = "Preview bucket and policy store from the site-previews module; set it to let the project's plan role deploy previews under <project>/ and store its content security policy"
  type = object({
    bucket  = string
    kvs_arn = string
  })
  default = null
}
