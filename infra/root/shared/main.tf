# Configuration
#
# What this variant needs exactly once, whatever the environment: the CI/CD role, and the CLI
# releases repo with the Actions variables the workflows read. Applied once (no workspaces), with the
# operator's credentials.
#
# Once per *account* is a different tier and belongs in the meta repo. This root is applied once per
# project, so anything account-wide put here would collide with the next project to apply it.

terraform {
  required_version = ">= 1.14"

  # 🎨 TEMPLATE EJECT: Change the state key to this project's prefix (backends take no variables)
  backend "s3" {
    bucket       = "ms-tfstate-aws-682544514886"
    key          = "projects/counter/aws/root/shared/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.11"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

module "global" {
  source = "../../common/global"
}

variable "gh_token" {
  description = "Organization-owned GitHub token."
  type        = string
  sensitive   = true
}

provider "github" {
  owner = module.global.gh_organization_name
  token = var.gh_token
}

data "github_repository" "this" {
  full_name = "${module.global.gh_organization_name}/${module.global.gh_repo_name}"
}

provider "aws" {
  region = module.global.aws_primary_location
}
