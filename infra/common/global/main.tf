terraform {
  required_version = ">= 1.14"
}

locals {
  # The deployment values that must stay identical between Terraform and the built artifacts (the
  # CLI) live once in infra/config and are read here from its emitted config.json, so neither side
  # can hardcode them independently and drift.
  config = jsondecode(file("${path.module}/../../config/config.json"))

  project_base_name   = local.config.project
  project_variant     = local.config.variant
  organization_domain = local.config.domain

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
