# API infrastructure

What the API needs to run, one instance per environment.

## Neon provisioning

The Neon project is created via the `kislerdm/neon` provider, which requires an API
key passed as the `neon_api_key` variable (set in CI via `TF_VAR_neon_api_key` /
the `NEON_API_KEY` secret).

The connection string targets Neon's **direct (non-pooled)** endpoint: the Lambda
opens one short-lived connection per request at low volume, so it stays well within
Neon's direct-connection limit and gains nothing from PgBouncer. The URL is built
from Neon's structured attributes rather than its `connection_uri`, because pgjdbc
rejects libpq-style `user:password@host` userinfo.

## Note: database credentials in Terraform state

The Neon connection string (including the password) is stored in Terraform state.
This is **unavoidable once Terraform provisions the Neon project**: the `neon`
provider exposes `connection_uri` / `database_password` as sensitive attributes that
land in state regardless of whether we also copy the URL into Secrets Manager. State
lives in the access-controlled, encrypted S3 backend bucket and the values are
marked `sensitive`. For this experimental template that is an acceptable trade-off.
Removing secrets from state entirely would require provisioning Neon out-of-band and
injecting the URL as a variable/data source, rather than managing it here.
