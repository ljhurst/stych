output "read_policy_json" {
  description = "Reads a Terraform plan needs for resource groups"
  value       = data.aws_iam_policy_document.read.json
}

output "write_policy_json" {
  description = "Writes a Terraform apply needs for resource groups"
  value       = data.aws_iam_policy_document.write.json
}
