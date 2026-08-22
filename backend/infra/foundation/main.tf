# Configuration

terraform {
  required_version = ">= 1.14"

  # 🎨 TEMPLATE EJECT: Change the state key to this project's prefix (backends take no variables)
  backend "s3" {
    bucket       = "ms-tfstate-aws-682544514886"
    key          = "projects/counter/aws/backend/foundation/terraform.tfstate"
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
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.18"
    }
  }
}

# Module imports

module "global" {
  source = "../../../infra/common/global"
}

module "environment" {
  source = "../../../infra/common/environment"
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
  description = "Cognito SPA app-client id; an audience the JWT authorizer accepts."
  type        = string
}

variable "cognito_cli_client_id" {
  description = "Cognito CLI app-client id; an audience the JWT authorizer accepts."
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token (manages the API custom domain's ACM DNS-validation records)."
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for the organization domain."
  type        = string
}

provider "neon" {
  api_key = var.neon_api_key
}

provider "aws" {
  region = module.global.aws_primary_location
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

