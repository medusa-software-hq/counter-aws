# Configuration

terraform {
  required_version = ">= 1.14"

  # 🎨 TEMPLATE EJECT: Change the state key to this project's prefix (backends take no variables)
  backend "s3" {
    bucket       = "ms-tfstate-aws-682544514886"
    key          = "projects/counter/aws/web-app/foundation/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
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

provider "aws" {
  region = module.global.aws_primary_location
}

# CloudFront only serves ACM certificates from us-east-1, regardless of where the
# rest of the app lives.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token (manages the ACM DNS-validation records)."
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for the organization domain."
  type        = string
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
