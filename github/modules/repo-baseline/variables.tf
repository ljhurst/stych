variable "repository" {
  description = "Repository name, without the owner"
  type        = string
}

variable "rulesets_supported" {
  description = "False for private repos on the free plan, where GitHub doesn't offer rulesets"
  type        = bool
  default     = true
}

variable "required_checks" {
  description = "Status check contexts that must pass before merging to the default branch"
  type        = list(string)
  default     = []
}

variable "prod_environment" {
  description = "Whether the repo deploys through a prod environment, which only the default branch may use"
  type        = bool
  default     = true
}
