# The CLI's releases repo: holds the `ms-counter` fat-jar assets that the
# Homebrew formula downloads. Provisioned here (root infra) because it is
# infrastructure for the CLI, alongside the Actions variables the Publish CLI
# workflow reads. The Homebrew *tap* is shared org-wide (medusa-software-hq/
# homebrew-tap) and is NOT managed here — this project only pushes counter.rb to
# it via the "Medusa Counter Releaser" GitHub App.
#
# 🎨 TEMPLATE POST-EJECT: install the releaser GitHub App on this repo, on the
# releases repo below, and on the shared homebrew-tap.
resource "github_repository" "counter_releases" {
  name        = module.global.gh_releases_repo_name
  description = "Release assets for the ${module.global.gh_repo_name} CLI."
  visibility  = "public"

  has_issues   = false
  has_projects = false
  has_wiki     = false

  # A release needs a default branch to target, so the repo must not be empty.
  auto_init = true

  # If the repo was created first, it has to be imported:
  # terraform import github_repository.counter_releases counter-aws-releases
}

# Give the repo its first commit through the contents API, so it has a default branch the Publish CLI
# workflow can cut releases against (an empty repo returns "Repository is empty"). This also seeds the
# controlled README; `auto_init` above covers a from-scratch recreate, this covers the existing repo.
resource "github_repository_file" "counter_releases_readme" {
  repository          = github_repository.counter_releases.name
  branch              = github_repository.counter_releases.default_branch
  file                = "README.md"
  content             = <<-MD
    # ${module.global.gh_releases_repo_name}

    Release assets for the `${module.global.gh_repo_name}` CLI. Populated by the Publish CLI workflow;
    the repository itself is managed by Terraform.
  MD
  commit_message      = "Initialise releases repository"
  overwrite_on_create = true
}
