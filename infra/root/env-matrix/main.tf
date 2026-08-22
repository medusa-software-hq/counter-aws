# Configuration
#
# Per-environment resources for this variant — one Terraform workspace per environment (`prod`,
# `staging`): the Cognito user pool + IdC federation and the per-environment Actions variables the
# deploys read. Applied with the operator's credentials.

terraform {
  required_version = ">= 1.14"

  # 🎨 TEMPLATE EJECT: Change the state key to this project's prefix (backends take no variables)
  backend "s3" {
    bucket       = "ms-tfstate-aws-682544514886"
    key          = "projects/counter/aws/root/env-matrix/terraform.tfstate"
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

module "global" {
  source = "../../common/global"
}

module "environment" {
  source = "../../common/environment"
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
