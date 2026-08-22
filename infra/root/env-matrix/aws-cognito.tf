# Cognito is the OIDC broker the SPA and CLI authenticate against; it federates
# to IAM Identity Center (the human directory) over SAML. The API validates the
# Cognito-issued JWT (issuer + audience below). Per environment (prod/staging
# each get their own pool), operator-applied with the rest of the root infra.
#
# The SAML trust is bidirectional and the IdC half is a console action, so *standing up a new
# environment* takes two passes. Every environment that
# exists is past that: an environment with no metadata URL below fails the plan rather than applying
# a pool that cannot federate.

# IdC SAML application metadata URL, per environment — each pool federates to its own IdC app,
# created with `automaton aws saml create`.
# 🎨 TEMPLATE BOOTSTRAP: Create a SAML application per environment and replace these URLs with the
# ones IdC returns 👇
variable "idc_saml_metadata_urls" {
  description = "IdC SAML application metadata URL per environment."
  type        = map(string)
  default = {
    prod    = "https://portal.sso.eu-central-1.amazonaws.com/saml/metadata/NjgyNTQ0NTE0ODg2X2lucy02OTg3MzUyNzdhNzdjOGU3"
    staging = "https://portal.sso.eu-central-1.amazonaws.com/saml/metadata/NjgyNTQ0NTE0ODg2X2lucy02OTg3NGZiY2Q2NTMwNWJj"
  }
}

locals {
  cognito_name = "${module.global.aws_resource_prefix}${module.environment.resource_name_suffix}"

  idc_saml_metadata_url = var.idc_saml_metadata_urls[module.environment.name]

  # Hosted-UI domain prefix. It must be globally unique and must NOT contain the
  # reserved words aws/amazon/cognito — so it cannot be derived from the
  # `counter-aws` resource prefix; use the org + project name and account id instead.
  cognito_domain_prefix = "${module.global.organization_name}-${module.global.project_base_name}${module.environment.resource_name_suffix}-${module.global.aws_account_id}"

  saml_provider_name = "IdC"
  # Federated users get their identities only from IdC; the pool itself is never an identity source.
  identity_providers = [local.saml_provider_name]

  web_url = "https://${module.environment.web_host_name}"
}

resource "aws_cognito_user_pool" "main" {
  name = local.cognito_name

  # Identities come from IdC, never self-service: no sign-up, admin-create only.
  admin_create_user_config {
    allow_admin_create_user_only = true
  }
  auto_verified_attributes = ["email"]

  # A pre-token Lambda stamps the user's IdC group names onto `cognito:groups`
  # (IdC SAML can't carry them — see aws-cognito-groups.tf).
  lambda_config {
    pre_token_generation = aws_lambda_function.pretoken.arn
  }

  # Custom attributes can't be dropped without recreating the pool, so this stays even though the
  # groups claim set by the pre-token Lambda is the path actually read.
  schema {
    name                = "groups"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = local.cognito_domain_prefix
  user_pool_id = aws_cognito_user_pool.main.id
}

# SAML federation to IdC.
resource "aws_cognito_identity_provider" "idc" {
  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = local.saml_provider_name
  provider_type = "SAML"

  provider_details = {
    MetadataURL = local.idc_saml_metadata_url
    IDPSignout  = "true"
  }

  attribute_mapping = {
    # Pool attribute = the assertion attribute the IdC application emits.
    email = "email"
  }

  # Cognito fetches the metadata from MetadataURL and stores the resolved
  # certificate/endpoints back into provider_details; ignore that so it doesn't
  # read as perpetual drift.
  lifecycle {
    ignore_changes = [provider_details]
  }
}

# SPA (browser): authorization code + PKCE against the Hosted UI. Public client
# (no secret).
resource "aws_cognito_user_pool_client" "spa" {
  name         = "${local.cognito_name}-spa"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret                      = false
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]

  callback_urls = [local.web_url, "${local.web_url}/", "http://localhost:5173", "http://localhost:5173/"]
  logout_urls   = [local.web_url, "http://localhost:5173"]

  supported_identity_providers = local.identity_providers

  read_attributes = ["email", "custom:groups"]

  depends_on = [aws_cognito_identity_provider.idc]
}

# CLI: also authorization code + PKCE, but with a loopback redirect — Cognito has
# no OAuth device-authorization grant, so the CLI opens a browser and catches the
# code on a fixed local port. Public client.
resource "aws_cognito_user_pool_client" "cli" {
  name         = "${local.cognito_name}-cli"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret                      = false
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]

  callback_urls = ["http://localhost:51789/callback"]
  logout_urls   = ["http://localhost:51789/logout"]

  supported_identity_providers = local.identity_providers

  read_attributes = ["email", "custom:groups"]

  depends_on = [aws_cognito_identity_provider.idc]
}

# The identity values the app builds read, surfaced as Actions variables.
resource "github_actions_environment_variable" "cognito" {
  for_each = {
    COGNITO_ISSUER_URL    = "https://cognito-idp.${module.global.aws_primary_location}.amazonaws.com/${aws_cognito_user_pool.main.id}"
    COGNITO_HOSTED_UI_URL = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${module.global.aws_primary_location}.amazoncognito.com"
    COGNITO_SPA_CLIENT_ID = aws_cognito_user_pool_client.spa.id
    COGNITO_CLI_CLIENT_ID = aws_cognito_user_pool_client.cli.id
  }

  repository    = data.github_repository.this.name
  environment   = module.environment.gh_environment_name
  variable_name = each.key
  value         = each.value
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "cognito_saml_sp_entity_id" {
  description = "SP entity id (audience) for the IdC SAML application."
  value       = "urn:amazon:cognito:sp:${aws_cognito_user_pool.main.id}"
}

output "cognito_saml_acs_url" {
  description = "SAML assertion consumer service URL for the IdC application."
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${module.global.aws_primary_location}.amazoncognito.com/saml2/idpresponse"
}

moved {
  from = aws_cognito_identity_provider.idc[0]
  to   = aws_cognito_identity_provider.idc
}
