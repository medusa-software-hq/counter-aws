terraform {
  required_version = ">= 1.14"
}

# infra/config is the single source; read it directly rather than the config.json it emits, so a
# regeneration that has not been run yet cannot make Terraform plan against stale values. The JSON
# exists for consumers that cannot run Terraform.
module "config" {
  source = "../../config"
}

locals {
  # The deployment environment IS the Terraform workspace — no default, so a root that forgot to
  # select one fails here rather than silently operating on another environment. Roots with no
  # environment dimension import the global module instead of this one.
  name = terraform.workspace

  config     = module.config.config
  env_config = local.config.environments[local.name]

  gh_environment_name  = local.env_config.gh_environment_name
  resource_name_suffix = local.env_config.resource_name_suffix

  # Subdomain under the organization domain, naming this environment's resources. The public hosts
  # themselves come straight from config.json.
  subdomain_label = "${local.config.project}-${local.config.variant}${local.resource_name_suffix}"

  api_subdomain_name = "api.${local.subdomain_label}"
  web_subdomain_name = local.subdomain_label
}

output "name" { value = local.name }

output "gh_environment_name" { value = local.gh_environment_name }

output "resource_name_suffix" { value = local.resource_name_suffix }

output "subdomain_label" { value = local.subdomain_label }

output "api_subdomain_name" { value = local.api_subdomain_name }

output "api_host_name" { value = local.env_config.api_host }

output "web_subdomain_name" { value = local.web_subdomain_name }

output "web_host_name" { value = local.env_config.web_host }
