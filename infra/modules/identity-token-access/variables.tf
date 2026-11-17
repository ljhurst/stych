variable "audiences" {
  description = "Audiences the project's roles may mint AWS-signed tokens for, e.g. https://api.anthropic.com"
  type        = list(string)
}
