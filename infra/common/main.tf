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

  # The deployment values that must stay identical between Terraform and the built artifacts (the
  # CLI) live once in infra/config and are read here from its emitted config.json, so neither side
  # can hardcode them independently and drift. Everything outside config.json is either shared across
  # environments (org, repo, AWS account, …) or derived below.
  config              = jsondecode(file("${path.module}/../config/config.json"))
  selected_env_config = local.config.environments[local.environment]

  project_base_name   = local.config.project
  project_variant     = local.config.variant
  organization_domain = local.config.domain

  gh_environment_name  = local.selected_env_config.gh_environment_name
  resource_name_suffix = local.selected_env_config.resource_name_suffix

  # The GitHub org + repo that holds the code and runs CI/CD — the SAME for
  # every environment (one repo, one Actions pipeline), so a flavor constant,
  # NOT part of the per-environment config. Used for the `github` provider owner
  # and Terraform state prefixes.
  gh_organization_name   = "medusa-software-hq" # 🎨 TEMPLATE EJECT: Change to your GitHub org
  gh_repo_name           = "counter-aws"        # 🎨 TEMPLATE EJECT: Change to your repository
  gh_default_branch_name = "trunk/aws"          # 🎨 TEMPLATE EJECT: Change the default branch

  # The releases repo the CLI publishes its fat jar to (provisioned by the root
  # infra), and the GitHub App the Publish CLI workflow authenticates as to push
  # releases + the Homebrew formula. Flavor constants — one app, one releases
  # repo, shared across environments.
  gh_releases_repo_name = "counter-aws-releases" # 🎨 TEMPLATE EJECT: Change to your releases repo
  # 🎨 TEMPLATE POST-EJECT: Create a GitHub App and change its client id here 👇
  gh_releases_client_id = "Iv23ct4SGbvxYw9pxJs8" # "Medusa Counter Releaser"

  # Short organization name, for globally-unique names that can't carry the resource prefix (the
  # Cognito Hosted-UI domain: AWS reserves aws/amazon/cognito, and this variant's prefix contains
  # "aws").
  organization_name = "medusa" # 🎨 TEMPLATE EJECT: Change to your organization's short name

  aws_primary_location = "eu-central-1" # 🎨 TEMPLATE EJECT: Change to your primary region
  aws_account_id       = "682544514886" # 🎨 TEMPLATE EJECT: Change to your AWS account id

  # Shared AWS state bucket — provisioned by the meta repo, keyed per repo.
  # Counter keys under `projects/<base>/<variant>/`. Also hard-coded in the
  # backend blocks, which take no variables.
  aws_state_bucket_name = "ms-tfstate-aws-${local.aws_account_id}"

  # Prefix for this variant's AWS resources, e.g. counter-aws-github-actions.
  aws_resource_prefix = "${local.project_base_name}-${local.project_variant}"

  # Subdomain under organization_domain — per environment (the suffix is empty
  # for prod). Used to name this variant's per-environment resources; the public
  # hosts themselves come straight from config.json (below).
  subdomain_label = "${local.project_base_name}-${local.project_variant}${local.resource_name_suffix}"

  # The API's public host, from config.json: the domain mapping publishes its DNS
  # record. Sourcing it from the single config keeps every use from drifting from
  # the deployed subdomain.
  api_subdomain_name = "api.${local.subdomain_label}"
  api_host_name      = local.selected_env_config.api_host

  # The web app's public host — the SPA is served here (CloudFront + ACM), and
  # the domain mapping points its DNS record at the distribution.
  web_subdomain_name = local.subdomain_label
  web_host_name      = local.selected_env_config.web_host
}

output "organization_domain" {
  value = local.organization_domain
}

output "organization_name" {
  value = local.organization_name
}

output "gh_organization_name" {
  value = local.gh_organization_name
}

output "gh_repo_name" {
  value = local.gh_repo_name
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


output "web_subdomain_name" {
  value = local.web_subdomain_name
}

output "web_host_name" {
  value = local.web_host_name
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
