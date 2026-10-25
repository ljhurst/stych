locals {
  check = "pre-commit / pre-commit"

  repos = {
    stych          = { private = false, required_checks = [local.check], prod_environment = false }
    lasso          = { private = false, required_checks = [local.check], prod_environment = true }
    porto          = { private = true, required_checks = [], prod_environment = true }
    victoria       = { private = false, required_checks = [local.check], prod_environment = true }
    train-spotting = { private = false, required_checks = [local.check], prod_environment = true }
    bracket-clash  = { private = false, required_checks = [local.check], prod_environment = true }
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
