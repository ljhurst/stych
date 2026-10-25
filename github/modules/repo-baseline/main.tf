resource "github_repository_ruleset" "default_branch" {
  count = var.rulesets_supported ? 1 : 0

  repository  = var.repository
  name        = "main"
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    deletion         = true
    non_fast_forward = true

    pull_request {
      allowed_merge_methods = ["merge", "squash", "rebase"]
    }

    dynamic "required_status_checks" {
      for_each = length(var.required_checks) > 0 ? [1] : []

      content {
        dynamic "required_check" {
          for_each = toset(var.required_checks)

          content {
            context = required_check.value
          }
        }
      }
    }
  }
}

# The apply roles trust this environment, so its branch policy is what keeps
# other branches from deploying.
resource "github_repository_environment" "prod" {
  count = var.prod_environment ? 1 : 0

  repository  = var.repository
  environment = "prod"

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "prod_main" {
  count = var.prod_environment ? 1 : 0

  repository     = var.repository
  environment    = github_repository_environment.prod[0].environment
  branch_pattern = "main"
}

resource "github_workflow_repository_permissions" "this" {
  repository                       = var.repository
  default_workflow_permissions     = "read"
  can_approve_pull_request_reviews = false
}

resource "github_repository_vulnerability_alerts" "this" {
  repository = var.repository
  enabled    = true
}

resource "github_repository_dependabot_security_updates" "this" {
  repository = var.repository
  enabled    = true

  depends_on = [github_repository_vulnerability_alerts.this]
}
