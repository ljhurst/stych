output "boundary_policy_json" {
  description = "Item-level access for the project's workload roles; the project adds it to its boundary"
  value       = data.aws_iam_policy_document.boundary.json
}

output "read_policy_json" {
  description = "Reads a Terraform plan needs for tables"
  value       = data.aws_iam_policy_document.read.json
}

output "write_policy_json" {
  description = "Writes a Terraform apply needs for tables"
  value       = data.aws_iam_policy_document.write.json
}

output "operate_policy_json" {
  description = "Local-only item-level access to the tables"
  value       = data.aws_iam_policy_document.operate.json
}
