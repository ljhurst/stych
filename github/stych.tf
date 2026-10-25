import {
  to = github_repository_ruleset.release_tags
  id = "stych:25836398"
}

# Release tags are immutable; only the floating v1 moves.
resource "github_repository_ruleset" "release_tags" {
  repository  = "stych"
  name        = "release tags"
  target      = "tag"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/tags/v*.*.*"]
      exclude = []
    }
  }

  rules {
    deletion = true
    update   = true
  }
}
