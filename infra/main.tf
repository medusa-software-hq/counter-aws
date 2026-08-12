# Configuration

terraform {
  required_version = ">= 1.14"

  # Shared state bucket, provisioned by the meta repo; the name is also in
  # common (backend blocks take no variables). Counter keys under its own
  # prefix; the default workspace (prod) keys at that prefix, other workspaces
  # get an `env:/<workspace>/` prefix.
  backend "s3" {
    bucket       = "ms-tfstate-aws-682544514886"
    key          = "projects/counter/aws/root/terraform.tfstate"
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
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

# Module imports

module "common" {
  source = "./common"
}

# Providers

# GitHub provider for writing CI/CD Actions variables. The repository itself is
# managed by the .github/config root; here it is only referenced as data.

variable "gh_token" {
  description = "Organization-owned GitHub token."
  type        = string
  sensitive   = true
}

provider "github" {
  owner = module.common.gh_organization_name
  token = var.gh_token
}

data "github_repository" "this" {
  full_name = "${module.common.gh_organization_name}/${module.common.gh_repo_name}"
}

# AWS
provider "aws" {
  region = module.common.aws_primary_location
}
