locals {
  check = "pre-commit / pre-commit"

  # ruleset_id and prod_policy_id are the existing settings imported into state.
  repos = {
    stych          = { private = false, required_checks = [local.check], prod_environment = false, ruleset_id = 25813384, prod_policy_id = null }
    lasso          = { private = false, required_checks = [local.check], prod_environment = true, ruleset_id = 25813786, prod_policy_id = 64277128 }
    porto          = { private = true, required_checks = [], prod_environment = true, ruleset_id = null, prod_policy_id = 64280371 }
    victoria       = { private = false, required_checks = [local.check], prod_environment = true, ruleset_id = 25834830, prod_policy_id = 64280083 }
    train-spotting = { private = false, required_checks = [local.check], prod_environment = true, ruleset_id = 25834848, prod_policy_id = 64329975 }
    bracket-clash  = { private = false, required_checks = [local.check], prod_environment = true, ruleset_id = 25834862, prod_policy_id = 64330014 }
  }
}

module "repo" {
  source   = "./modules/repo-baseline"
  for_each = local.repos

  repository         = each.key
  rulesets_supported = !each.value.private
  required_checks    = each.value.required_checks
  prod_environment   = each.value.prod_environment
}

import {
  for_each = { for name, r in local.repos : name => r if r.ruleset_id != null }
  to       = module.repo[each.key].github_repository_ruleset.default_branch[0]
  id       = "${each.key}:${each.value.ruleset_id}"
}

import {
  for_each = { for name, r in local.repos : name => r if r.prod_policy_id != null }
  to       = module.repo[each.key].github_repository_environment.prod[0]
  id       = "${each.key}:prod"
}

import {
  for_each = { for name, r in local.repos : name => r if r.prod_policy_id != null }
  to       = module.repo[each.key].github_repository_environment_deployment_policy.prod_main[0]
  id       = "${each.key}:prod:${each.value.prod_policy_id}"
}

import {
  for_each = local.repos
  to       = module.repo[each.key].github_workflow_repository_permissions.this
  id       = each.key
}
