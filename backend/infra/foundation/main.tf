# Configuration

terraform {
  required_version = ">= 1.14"

  backend "s3" {
    bucket       = "ms-tfstate-aws-682544514886"
    key          = "projects/counter/aws/api/foundation/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    neon = {
      source  = "kislerdm/neon"
      version = "~> 0.9"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Module imports

module "common" {
  source = "../../../infra/common"
}

# Providers

variable "neon_api_key" {
  description = "Neon API key used to provision the serverless Postgres project."
  type        = string
  sensitive   = true
}

# The counter is in-memory for now, so no Neon resources exist in this configuration. The provider is
# retained so Terraform can destroy the previously-provisioned project on apply, and because a later
# slice re-introduces Postgres-backed persistence.
provider "neon" {
  api_key = var.neon_api_key
}

provider "aws" {
  region = module.common.aws_primary_location
}

