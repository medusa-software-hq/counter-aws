# Client id of the "Medusa Counter Releaser" GitHub App the Publish CLI workflow authenticates as
# (public; the private key is a secret). Repository-scoped, not per-environment — it's one App for the
# whole repo — and sourced from the infra/common constant (it's a value we obtained once, not a
# Terraform-created resource).
resource "github_actions_variable" "gh_releases_client_id" {
  repository    = data.github_repository.this.name
  variable_name = "GH_RELEASES_CLIENT_ID"
  value         = module.global.gh_releases_client_id
}

# The releases repo the Publish CLI workflow cuts releases against. It scopes its App token to that
# repo before doing anything else, so it needs the name up front.
resource "github_actions_variable" "gh_releases_repo_name" {
  repository    = data.github_repository.this.name
  variable_name = "GH_RELEASES_REPO_NAME"
  value         = github_repository.counter_releases.name
}
