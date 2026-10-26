variable "domain_name" {
  description = "Hostname the service is served from, e.g. porto.bylukehurst.com; a wildcard certificate for its parent domain must exist in us-east-1, which must be the default provider's region"
  type        = string
}

variable "function_url" {
  description = "The Lambda Function URL CloudFront forwards to, e.g. aws_lambda_function_url.porto.function_url"
  type        = string
}

variable "origin_timeout" {
  description = "Seconds CloudFront waits for the function to respond; set it at least as high as the function's own timeout. The account's 'Response timeout per origin' quota caps it (120 by default)"
  type        = number
  default     = 60

  validation {
    condition     = var.origin_timeout >= 1 && var.origin_timeout <= 120
    error_message = "origin_timeout must be between 1 and 120 seconds"
  }
}
