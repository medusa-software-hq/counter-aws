# Configuration
#
# The public DNS record is split out from the web foundation to mirror the API:
# the record points at infrastructure the foundation owns (the CloudFront
# distribution), so it is applied after — and separately from — the foundation.

terraform {
  required_version = ">= 1.14"

  backend "s3" {
    bucket       = "ms-tfstate-aws-682544514886"
    key          = "projects/counter/aws/apps/web/domain-mapping/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.18"
    }
  }
}

# Module imports

module "common" {
  source = "../../../infra/common"
}

# The web foundation's outputs (the CloudFront distribution this record targets).
data "terraform_remote_state" "web_foundation" {
  backend = "s3"
  config = {
    bucket = module.common.aws_state_bucket_name
    key    = "projects/counter/aws/apps/web/foundation/terraform.tfstate"
    region = module.common.aws_primary_location
  }
}

# Providers

variable "cloudflare_api_token" {
  description = "Cloudflare API token."
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
