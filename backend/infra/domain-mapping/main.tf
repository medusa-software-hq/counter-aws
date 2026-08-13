# Configuration
#
# The API's public DNS record is split out from the API foundation, mirroring the web app's
# domain-mapping: the foundation owns the AWS resources (the ACM cert, the API Gateway custom domain,
# and the mapping), and this root owns only the public Cloudflare record that points a human-facing
# host at them.

terraform {
  required_version = ">= 1.14"

  backend "s3" {
    bucket       = "ms-tfstate-aws-682544514886"
    key          = "projects/counter/aws/api/domain-mapping/terraform.tfstate"
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

# The API foundation exposes the regional API Gateway hostname the DNS record points at.
data "terraform_remote_state" "api_foundation" {
  backend = "s3"
  config = {
    bucket = module.common.aws_state_bucket_name
    key    = "projects/counter/aws/api/foundation/terraform.tfstate"
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
