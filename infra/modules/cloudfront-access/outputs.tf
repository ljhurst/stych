output "read_policy_json" {
  description = "Reads a Terraform plan needs; add to the project's read policy as a source document"
  value       = data.aws_iam_policy_document.read.json
}

output "write_policy_json" {
  description = "Writes a Terraform apply needs; add to the project's write policy as a source document"
  value       = data.aws_iam_policy_document.write.json
}
