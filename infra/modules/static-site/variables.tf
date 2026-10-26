variable "bucket_name" {
  description = "Private S3 bucket the site is deployed to"
  type        = string
}

variable "domain_name" {
  description = "Hostname the site is served from, e.g. bracket-clash.bylukehurst.com; a wildcard certificate for its parent domain must exist in us-east-1, which must be the default provider's region"
  type        = string
}

variable "content_security_policy" {
  description = "Content-Security-Policy header value"
  type        = string
  default     = "default-src 'self'"
}
