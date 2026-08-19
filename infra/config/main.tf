terraform {
  required_version = ">= 1.14"
}

locals {
  # Shared across every environment; combined into per-environment derived values.
  project = "counter"         # 🎨 TEMPLATE EJECT: Choose an org-unique project base name
  variant = "aws"             # 🎨 TEMPLATE EJECT: Choose a project-unique variant name
  domain  = "medusa.software" # 🎨 TEMPLATE EJECT: Change to your organization's domain

  # Hand-edited per-environment static constants (the GitHub deployment Environment name and the
  # resource-name suffix). The single source of truth for values that must stay identical between
  # Terraform and the built artifacts (the CLI).
  environments = {
    prod = {
      gh_environment_name  = "production"
      resource_name_suffix = ""
    }
    staging = {
      gh_environment_name  = "staging"
      resource_name_suffix = "-staging"
    }
  }

  # The emitted contract written to config.json, which the non-Terraform consumers read. Per
  # environment: every source field plus the derived public web/API hosts (from
  # project/variant/suffix/domain exactly as the deployed subdomains are — see infra/common).
  config = {
    project = local.project
    variant = local.variant
    domain  = local.domain
    environments = {
      for env, config in local.environments : env => merge(config, {
        web_host = "${local.project}-${local.variant}${config.resource_name_suffix}.${local.domain}"
        api_host = "api.${local.project}-${local.variant}${config.resource_name_suffix}.${local.domain}"
      })
    }
  }
}

output "config" {
  value = local.config
}
