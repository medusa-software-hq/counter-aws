# Project-level Terraform

The lowest-level configuration, split by lifecycle:

| Path               | State / workspaces                          | Holds                                                                 |
| ------------------ | ------------------------------------------- | --------------------------------------------------------------------- |
| `root/shared/`     | one state, no workspaces                    | Account-level singletons: the CI/CD role, ECR, the releases repo + its Actions variable, the API Gateway service-linked role. |
| `root/env-matrix/` | one workspace per environment (`prod`, …)   | Per-environment resources: the Cognito user pool + IdC federation and the `COGNITO_*` Actions variables. |
| `config/`          | pure locals, no cloud auth                  | The author-derived values emitted to `config.json` (hosts, env metadata) that the CLI and other non-Terraform consumers read. |
| `common/`          | module (no state)                           | Values shared by the roots — names, the selected environment, `config.json` decoded. |

Both roots are applied with the operator's credentials (they manage IAM and account singletons the
CI/CD role can't). `config/` needs no cloud access at all.

<!-- 🎨 TEMPLATE POST-EJECT: Apply this configuration -->
