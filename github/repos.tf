locals {
  check = "pre-commit / pre-commit"

  repos = {
    stych          = { private = false, required_checks = [local.check], prod_environment = false, require_pull_request = true }
    lasso          = { private = false, required_checks = [local.check], prod_environment = true, require_pull_request = true }
    porto          = { private = true, required_checks = [], prod_environment = true, require_pull_request = true }
    victoria       = { private = false, required_checks = [local.check], prod_environment = true, require_pull_request = true }
    train-spotting = { private = false, required_checks = [local.check], prod_environment = true, require_pull_request = true }
    bracket-clash  = { private = false, required_checks = [local.check], prod_environment = true, require_pull_request = true }
    fife           = { private = false, required_checks = [], prod_environment = true, require_pull_request = true }
    aboutme        = { private = false, required_checks = [], prod_environment = false, require_pull_request = true }
    sommething     = { private = false, required_checks = [], prod_environment = false, require_pull_request = true }
    dio            = { private = false, required_checks = [local.check], prod_environment = true, require_pull_request = true }
    interview      = { private = false, required_checks = [], prod_environment = false, require_pull_request = false }
    dotfiles       = { private = false, required_checks = [], prod_environment = false, require_pull_request = false }
  }
}

module "repo" {
  source   = "./modules/repo-baseline"
  for_each = local.repos

  repository           = each.key
  rulesets_supported   = !each.value.private
  required_checks      = each.value.required_checks
  prod_environment     = each.value.prod_environment
  require_pull_request = each.value.require_pull_request
}
