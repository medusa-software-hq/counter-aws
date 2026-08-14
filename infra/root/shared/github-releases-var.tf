# Client id of the "Medusa Counter Releaser" GitHub App the Publish CLI workflow authenticates as
# (public; the private key is a secret). Repository-scoped, not per-environment — it's one App for the
# whole repo — and sourced from the infra/common constant (it's a value we obtained once, not a
# Terraform-created resource).
resource "github_actions_variable" "gh_releases_client_id" {
  repository    = data.github_repository.this.name
  variable_name = "GH_RELEASES_CLIENT_ID"
  value         = module.common.gh_releases_client_id
}
