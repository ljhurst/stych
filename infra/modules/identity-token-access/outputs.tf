output "boundary_policy_json" {
  description = "Lets the project's roles mint tokens for the listed audiences; the project adds it to its boundary"
  value       = data.aws_iam_policy_document.boundary.json
}
