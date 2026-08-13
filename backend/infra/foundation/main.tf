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

variable "cognito_issuer_url" {
  description = "Cognito user-pool issuer URL; the API Gateway JWT authorizer validates ID tokens against it."
  type        = string
}

variable "cognito_spa_client_id" {
  description = "Cognito SPA app-client id; the audience the JWT authorizer requires."
  type        = string
}

# Neon (serverless Postgres) backs the counter store; see neon.tf.
provider "neon" {
  api_key = var.neon_api_key
}

provider "aws" {
  region = module.common.aws_primary_location
}

