# Project-level Terraform

The lowest-level configuration, split by lifecycle:

| Path                  | State / workspaces                                | Role                                                             |
| --------------------- | ------------------------------------------------- | ---------------------------------------------------------------- |
| `root/shared/`        | one state, no workspaces                          | What exists once for the account, whatever the environment.       |
| `root/env-matrix/`    | one workspace per environment (`prod`, `staging`) | The identity plane, one instance per environment.                 |
| `common/global/`      | module (no state)                                 | Everything this project declares that no environment varies, and the source `config.json` is emitted from. |
| `common/environment/` | module (no state)                                 | Resolves one environment from the workspace. A root without an environment does not import it. |
| `config/`             | no Terraform                                      | Holds the emitted `config.json` for consumers that cannot run Terraform. |

Both roots are applied with the operator's credentials: they manage IAM and account singletons the
CI/CD role deliberately cannot touch.

## Adding an environment

Cognito federates to an IdC SAML application, and creating that application is a console action
(`automaton aws saml create`) that needs identifiers only the pool can give it. So a new environment
is stood up in two passes:

1. Add it to `config/`, and add its key to `idc_saml_metadata_urls` with an empty value — the URL
   doesn't exist yet, and a key that is missing entirely fails the plan.
2. Select the new workspace and apply just the pool and its Hosted-UI domain:

   ```
   terraform apply -target=aws_cognito_user_pool.main -target=aws_cognito_user_pool_domain.main
   ```

3. Create the SAML application from the `cognito_saml_sp_entity_id` and `cognito_saml_acs_url`
   outputs, and take the metadata URL IdC returns.
4. Put that URL in `idc_saml_metadata_urls` and apply the root in full.

Between steps 2 and 4 the environment is half-built: a full apply fails on the federation, because an
empty metadata URL is not a valid SAML provider. That is deliberate — it fails loudly rather than
leaving a pool that looks fine and cannot federate.

<!-- 🎨 TEMPLATE POST-EJECT: Apply this configuration -->
