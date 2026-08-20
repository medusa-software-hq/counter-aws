# Deployment configuration

`config.json` holds the deployment values that must stay identical between the Terraform that
provisions the environments and the artifacts built from this repo (the CLI) — the values neither
side may hardcode independently without drifting.

It is **generated**, not edited: the source is the shared module's locals, and Terraform reads those
directly rather than this file. It is committed so consumers that can't run Terraform can read it.
Regenerate after editing the source with `task config:regenerate`; CI re-emits and fails on any
diff, so the committed copy can't go stale.
