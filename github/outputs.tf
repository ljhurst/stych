output "public_repos" {
  description = "Repos whose fork-PR approval scripts/apply-fork-approval.sh sets"
  value       = sort([for name, r in local.repos : name if !r.private])
}

output "repos" {
  description = "Every repo in repos.tf, for scripts that set what the module can't"
  value       = sort(keys(local.repos))
}
