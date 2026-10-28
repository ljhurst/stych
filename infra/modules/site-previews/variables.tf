variable "bucket_name" {
  description = "Private S3 bucket every project's pull request previews are deployed to, under <project>/pr-<number>/"
  type        = string
}

variable "domain_name" {
  description = "Parent domain of the preview hostnames, e.g. preview.bylukehurst.com; previews are served at <project>-pr-<number>.<domain_name>"
  type        = string
}

variable "expire_days" {
  description = "Days after which a preview's objects are deleted, so previews of PRs that never got cleaned up don't accumulate"
  type        = number
  default     = 14
}
