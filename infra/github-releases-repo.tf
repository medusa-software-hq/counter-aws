# The CLI's releases repo: holds the `ms-counter` fat-jar assets that the
# Homebrew formula downloads. Provisioned here (root infra) because it is
# infrastructure for the CLI, alongside the Actions variables the Publish CLI
# workflow reads. The Homebrew *tap* is shared org-wide (medusa-software-hq/
# homebrew-tap) and is NOT managed here — this project only pushes counter.rb to
# it via the "Medusa Counter Releaser" GitHub App.
#
# 🎨 TEMPLATE POST-EJECT: install the releaser GitHub App on this repo, on the
# releases repo below, and on the shared homebrew-tap.
# A single shared repo, so only the default (prod) workspace owns it; other workspaces must not
# contend for the same GitHub repo. The moved block relocates the pre-count resource in prod
# state rather than destroy/recreate it.
resource "github_repository" "counter_releases" {
  count = module.common.environment == "prod" ? 1 : 0

  name        = module.common.gh_releases_repo_name
  description = "Release assets for the ${module.common.gh_repo_name} CLI."
  visibility  = "public"

  has_issues   = false
  has_projects = false
  has_wiki     = false

  # If the repo was created first, it has to be imported:
  # terraform import github_repository.counter_releases counter-aws-releases
}

moved {
  from = github_repository.counter_releases
  to   = github_repository.counter_releases[0]
}
