terraform {
  required_version = ">= 1.14"
}

locals {
  project_base_name   = "counter"         # 🎨 TEMPLATE EJECT: Choose an org-unique project base name
  project_variant     = "aws"             # 🎨 TEMPLATE EJECT: Choose a project-unique variant name
  organization_domain = "medusa.software" # 🎨 TEMPLATE EJECT: Change to your organization's domain

  # The environments this project has, and what genuinely differs between them. Resolving one is the
  # environment module's job; this module only declares them, so it never depends on a workspace.
  declared_environments = {
    prod = {
      gh_environment_name  = "production"
      resource_name_suffix = ""
    }
    staging = {
      gh_environment_name  = "staging"
      resource_name_suffix = "-staging"
    }
  }

  # Every name derived from an environment, spelled HERE and nowhere else. Both consumers read these
  # rather than rebuilding them: the resources through the environment module, the CLI through the
  # emitted contract. A second derivation would let the artifact and the deployed subdomain disagree
  # — the exact drift the emitted contract exists to prevent, and one no diff of it would catch.
  resource_labels = {
    for env, config in local.declared_environments :
    env => "${local.aws_resource_prefix}${config.resource_name_suffix}"
  }

  # The API's subdomain prefix, shared by every environment — the CI role scopes its custom-domain
  # grant with it.
  api_subdomain_prefix = "api.${local.aws_resource_prefix}"

  environments = {
    for env, config in local.declared_environments : env => merge(config, {
      resource_label     = local.resource_labels[env]
      api_subdomain_name = "api.${local.resource_labels[env]}"
      web_subdomain_name = local.resource_labels[env]
      api_host           = "api.${local.resource_labels[env]}.${local.organization_domain}"
      web_host           = "${local.resource_labels[env]}.${local.organization_domain}"
    })
  }

  # One repo and one Actions pipeline serve every environment, so these are flavor constants rather
  # than per-environment config.
  gh_organization_name   = "medusa-software-hq" # 🎨 TEMPLATE EJECT: Change to your GitHub org
  gh_repo_name           = "counter-aws"        # 🎨 TEMPLATE EJECT: Change to your repository
  gh_default_branch_name = "trunk/aws"          # 🎨 TEMPLATE EJECT: Change the default branch

  # The releases repo the CLI publishes its fat jar to, and the GitHub App the publish workflow
  # authenticates as. One app, one releases repo, shared across environments.
  gh_releases_repo_name = "counter-aws-releases" # 🎨 TEMPLATE EJECT: Change to your releases repo
  # 🎨 TEMPLATE POST-EJECT: Create a GitHub App and change its client id here 👇
  gh_releases_client_id = "Iv23ct4SGbvxYw9pxJs8" # "Medusa Counter Releaser"

  # Short organization name, for globally-unique names that can't be built from the resource prefix.
  organization_name = "medusa" # 🎨 TEMPLATE EJECT: Change to your organization's short name

  aws_primary_location = "eu-central-1" # 🎨 TEMPLATE EJECT: Change to your primary region
  aws_account_id       = "682544514886" # 🎨 TEMPLATE EJECT: Change to your AWS account id

  # Provisioned by the meta repo, keyed per repo. Also hard-coded in the backend blocks, which take
  # no variables.
  aws_state_bucket_name = "ms-tfstate-aws-${local.aws_account_id}"

  aws_resource_prefix = "${local.project_base_name}-${local.project_variant}"
}

output "organization_domain" { value = local.organization_domain }

output "organization_name" { value = local.organization_name }

output "gh_organization_name" { value = local.gh_organization_name }

output "gh_repo_name" { value = local.gh_repo_name }

output "gh_default_branch_name" { value = local.gh_default_branch_name }

output "gh_releases_repo_name" { value = local.gh_releases_repo_name }

output "gh_releases_client_id" { value = local.gh_releases_client_id }

output "project_base_name" { value = local.project_base_name }

output "project_variant" { value = local.project_variant }

output "aws_primary_location" { value = local.aws_primary_location }

output "aws_account_id" { value = local.aws_account_id }

output "aws_state_bucket_name" { value = local.aws_state_bucket_name }

output "aws_resource_prefix" { value = local.aws_resource_prefix }

# The contract emitted to config.json for consumers that cannot run Terraform — today the CLI, which
# bakes the API host per environment. Deliberately narrow: everything above stays out of the
# published binary unless it is named here. The hosts are derived, so a subdomain can never be
# spelled differently in the artifact than in the resources.
locals {
  config = {
    project = local.project_base_name
    variant = local.project_variant
    domain  = local.organization_domain
    environments = {
      for env, config in local.environments : env => {
        gh_environment_name  = config.gh_environment_name
        resource_name_suffix = config.resource_name_suffix
        api_host             = config.api_host
        web_host             = config.web_host
      }
    }
  }
}

output "api_subdomain_prefix" { value = local.api_subdomain_prefix }

output "config" { value = local.config }

output "environments" { value = local.environments }
