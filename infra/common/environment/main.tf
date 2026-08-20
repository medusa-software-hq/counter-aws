terraform {
  required_version = ">= 1.14"
}

module "global" {
  source = "../global"
}

locals {
  # The deployment environment IS the Terraform workspace — no default, so a root that forgot to
  # select one fails here rather than silently operating on another environment. Roots with no
  # environment dimension import the global module instead of this one.
  name = terraform.workspace

  # Selection only. Every value below is derived once, where the environments are declared.
  env = module.global.environments[local.name]
}

output "name" { value = local.name }

output "gh_environment_name" { value = local.env.gh_environment_name }

output "resource_name_suffix" { value = local.env.resource_name_suffix }

output "resource_label" { value = local.env.resource_label }

output "api_subdomain_name" { value = local.env.api_subdomain_name }

output "api_host_name" { value = local.env.api_host }

output "web_subdomain_name" { value = local.env.web_subdomain_name }

output "web_host_name" { value = local.env.web_host }
