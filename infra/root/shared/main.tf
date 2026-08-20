# Configuration
#
# Account-level singletons for this variant, shared across environments: the CI/CD role + registry,
# the CLI releases repo + its Actions variable, and the API Gateway service-linked role. Applied once
# (no workspaces), with the operator's credentials.

terraform {
  required_version = ">= 1.14"

  # 🎨 TEMPLATE EJECT: Change the state bucket + key (backends take no variables)
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
