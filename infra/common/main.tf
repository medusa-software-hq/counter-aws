terraform {
  required_version = ">= 1.14"
}

locals {
  # Deployment environment, derived from the Terraform workspace. The `default`
  # workspace is production — its state predates the prod/staging split, so it
  # stays in place (no state migration); every other workspace is a named
  # non-prod environment. This is the single dimension that distinguishes prod
  # from staging across every root that imports this module.
  environment = terraform.workspace == "default" ? "prod" : terraform.workspace

  # Per-environment values. Everything *outside* this map is shared across
  # environments (same org, repo, domain, …);
  # only what genuinely differs per environment lives here. `default`/prod
  # resolves to exactly the values used before this split, so introducing the
  # workspace dimension is a no-op on the prod state.
  environment_config = {
    prod = {
      # The GitHub deployment Environment holding this environment's Actions
      # variables (see .github/config). Note prod's is "production", not "prod".
      gh_environment_name = "production"

      # DNS/Neon-safe suffix appended to derived resource names (web/API
      # subdomain, Neon project). Empty for prod so its subdomain and Neon
      # project keep their pre-split names.
      resource_name_suffix = ""
    }
    staging = {
      gh_environment_name  = "staging"
      resource_name_suffix = "-staging"
    }
  }
  selected_environment = local.environment_config[local.environment]

  organization_domain = "medusa.software"

  # The GitHub org + repo that holds the code and runs CI/CD — the SAME for
  # every environment (one repo, one Actions pipeline), so a flavor constant,
  # NOT part of environment_config. Used for the `github` provider owner and
  # Terraform state prefixes.
  gh_organization_name   = "medusa-software-hq"
  gh_repo_name           = "counter-aws"
  gh_api_url_var_name    = "API_URL"
  gh_default_branch_name = "trunk/aws" # 🎨 TEMPLATE EJECT: Change the default branch

  # The releases repo the CLI publishes its fat jar to (provisioned by the root
  # infra), and the GitHub App the Publish CLI workflow authenticates as to push
  # releases + the Homebrew formula. Flavor constants — one app, one releases
  # repo, shared across environments.
  gh_releases_repo_name = "counter-aws-releases"
  # 🎨 TEMPLATE POST-EJECT: Create a GitHub App and change its client id here 👇
  gh_releases_client_id = "Iv23ct4SGbvxYw9pxJs8" # "Medusa Counter Releaser"

  project_base_name = "counter" # 🎨 TEMPLATE EJECT: Choose an org-unique project base name
  project_variant   = "aws"     # 🎨 TEMPLATE EJECT: Choose a project-unique variant name

  aws_primary_location = "eu-central-1"
  aws_account_id       = "682544514886"

  # Shared AWS state bucket — provisioned by the meta repo, keyed per repo.
  # Counter keys under `projects/<base>/<variant>/`. Also hard-coded in the
  # backend blocks, which take no variables.
  aws_state_bucket_name = "ms-tfstate-aws-${local.aws_account_id}"

  # Prefix for this variant's AWS resources, e.g. counter-aws-github-actions.
  aws_resource_prefix = "${local.project_base_name}-${local.project_variant}"

  gh_environment_name  = local.selected_environment.gh_environment_name
  resource_name_suffix = local.selected_environment.resource_name_suffix

  # Subdomain under organization_domain — per environment (the suffix is empty
  # for prod). The web app is published at `<subdomain_label>.<domain>` and the
  # API at `api.<subdomain_label>.<domain>`; staging gets its own subdomain for
  # free.
  subdomain_label = "${local.project_base_name}-${local.project_variant}${local.resource_name_suffix}"

  # The API's public host, defined once: the domain mapping publishes it (DNS
  # record) and CI/CD hands it to the web build as VITE_API_URL. Two definitions
  # of the same string would silently drift the moment the subdomain changed.
  api_subdomain_name = "api.${local.subdomain_label}"
  api_host_name      = "${local.api_subdomain_name}.${local.organization_domain}"
  api_url            = "https://${local.api_host_name}"
}

output "organization_domain" {
  value = local.organization_domain
}

output "gh_organization_name" {
  value = local.gh_organization_name
}

output "gh_repo_name" {
  value = local.gh_repo_name
}

output "gh_api_url_var_name" {
  value = local.gh_api_url_var_name
}

output "project_base_name" {
  value = local.project_base_name
}

output "project_variant" {
  value = local.project_variant
}

output "aws_primary_location" {
  value = local.aws_primary_location
}

output "aws_account_id" {
  value = local.aws_account_id
}

output "aws_state_bucket_name" {
  value = local.aws_state_bucket_name
}

output "aws_resource_prefix" {
  value = local.aws_resource_prefix
}

output "subdomain_label" {
  value = local.subdomain_label
}

output "api_subdomain_name" {
  value = local.api_subdomain_name
}

output "api_host_name" {
  value = local.api_host_name
}

output "api_url" {
  value = local.api_url
}

output "gh_releases_repo_name" {
  value = local.gh_releases_repo_name
}

output "gh_releases_client_id" {
  value = local.gh_releases_client_id
}

output "environment" {
  value = local.environment
}

output "gh_environment_name" {
  value = local.gh_environment_name
}

output "gh_default_branch_name" {
  value = local.gh_default_branch_name
}

output "resource_name_suffix" {
  value = local.resource_name_suffix
}
