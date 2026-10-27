variable "bucket_name" {
  description = "Private S3 bucket the site is deployed to"
  type        = string
}

variable "domain_name" {
  description = "Hostname the site is served from, e.g. bracket-clash.bylukehurst.com; a wildcard certificate for its parent domain must exist in us-east-1, which must be the default provider's region"
  type        = string
}

variable "region" {
  description = "Region of the site's bucket; defaults to the provider's region. CloudFront and its certificate stay in us-east-1 either way"
  type        = string
  default     = null
}

variable "content_security_policy" {
  description = "Content-Security-Policy header value"
  type        = string
  default     = "default-src 'self'"
}

variable "directory_index" {
  description = "Serve /dir/ and /dir as /dir/index.html, for sites built with one HTML file per page"
  type        = bool
  default     = false
}
