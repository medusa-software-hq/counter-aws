# Backend API Terraform configuration

Provisions the resources the API needs, per environment (one Terraform workspace
each):

- the API Lambda — a GraalVM-native custom-runtime zip — and its execution role
- an API Gateway HTTP API in front of it, with a Cognito JWT authorizer gating
  every route
- the API's custom domain: an ACM certificate validated over Cloudflare DNS, the
  domain's API mapping, and the public DNS record
- a **Neon serverless Postgres** project backing the counter store
- a Secrets Manager secret holding the Neon JDBC connection string; the Lambda
  gets the secret's **ARN** as an environment variable and reads the string at
  startup, so the password never lands in the function's plaintext config

## Neon provisioning

The Neon project is created via the `kislerdm/neon` provider, which requires an API
key passed as the `neon_api_key` variable (set in CI via `TF_VAR_neon_api_key` /
the `NEON_API_KEY` secret).

The connection string targets Neon's **direct (non-pooled)** endpoint: the Lambda
opens one short-lived connection per request at low volume, so it stays well within
Neon's direct-connection limit and gains nothing from PgBouncer. The URL is built
from Neon's structured attributes rather than its `connection_uri`, because pgjdbc
rejects libpq-style `user:password@host` userinfo.

The schema is owned by SQLDelight and applied by the handler on a cold start; there
is no separate migration tool.

## Note: database credentials in Terraform state

The Neon connection string (including the password) is stored in Terraform state.
This is **unavoidable once Terraform provisions the Neon project**: the `neon`
provider exposes `connection_uri` / `database_password` as sensitive attributes that
land in state regardless of whether we also copy the URL into Secrets Manager. State
lives in the access-controlled, encrypted S3 backend bucket and the values are
marked `sensitive`. For this experimental template that is an acceptable trade-off.
Removing secrets from state entirely would require provisioning Neon out-of-band and
injecting the URL as a variable/data source, rather than managing it here.
