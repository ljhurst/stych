output "plan_role_arn" {
  description = "Role a PR's plan job assumes"
  value       = aws_iam_role.ci["plan"].arn
}

output "apply_role_arn" {
  description = "Role the apply job on main assumes"
  value       = aws_iam_role.ci["apply"].arn
}

output "boundary_policy_arn" {
  description = "Permissions boundary every workload role in the project must carry"
  value       = aws_iam_policy.this["boundary"].arn
}
