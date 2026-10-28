output "boundary_policy_json" {
  description = "Boundary for the project-access module"
  value       = data.aws_iam_policy_document.boundary.json
}

output "read_policy_json" {
  description = "Reads a Terraform plan needs"
  value       = data.aws_iam_policy_document.read.json
}

output "write_policy_json" {
  description = "Writes a Terraform apply and a site deploy need"
  value       = data.aws_iam_policy_document.write.json
}

output "operate_policy_json" {
  description = "Local-only access to the site's objects"
  value       = data.aws_iam_policy_document.operate.json
}

output "preview_policy_json" {
  description = "Deploys pull request previews to the project's prefix of the preview bucket; null unless preview_bucket is set"
  value       = one(data.aws_iam_policy_document.preview[*].json)
}
