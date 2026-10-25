terraform {
  required_version = ">= 1.10"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
  }
}

# Authenticates with GITHUB_TOKEN, e.g. `export GITHUB_TOKEN=$(gh auth token)`.
provider "github" {
  owner = "ljhurst"
}
