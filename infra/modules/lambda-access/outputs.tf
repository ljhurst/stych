output "boundary_policy_json" {
  description = "Reads parameters and writes logs; the project adds what its own roles need"
  value       = data.aws_iam_policy_document.boundary.json
}

output "read_policy_json" {
  description = "Reads a Terraform plan needs for functions, log groups and resource groups"
  value       = data.aws_iam_policy_document.read.json
}

output "write_policy_json" {
  description = "Writes a Terraform apply needs for functions, log groups and resource groups"
  value       = data.aws_iam_policy_document.write.json
}

output "operate_policy_json" {
  description = "Local-only access to parameters and logs"
  value       = data.aws_iam_policy_document.operate.json
}
