# Counter

An experimental internal project — a small full-stack "counter" app that doubles as a template for
other internal services. This variant runs entirely on **AWS**, serverless.

## Architecture

Three layers, contract-first:

- **Frontend SPA** — a React/Vite/Mantine app, hosted as static files on S3 behind CloudFront.
- **Backend API** — a Kotlin/Micronaut service compiled to a GraalVM native image and run on a Lambda
  custom runtime, fronted by API Gateway.
- **API contract** — an OpenAPI document from which both the server controllers and the clients are
  generated.

At runtime:

```text
Browser
  -> React SPA on S3 + CloudFront
  -> Cognito Hosted UI for sign-in (OIDC)
  -> CloudFront routes /api to API Gateway (HTTP API)
  -> Cognito JWT authorizer validates the ID token
  -> Micronaut Lambda (GraalVM native)
  -> Neon (serverless Postgres) via SQLDelight
```

The SPA and API share an origin: the SPA calls `/api` on its own host, and CloudFront routes that
prefix to API Gateway, so there is no cross-origin hop.

### Layout

- `web-app/frontend/` — the SPA
- `backend/api/openapi/` — the OpenAPI contract (the source of truth for both sides)
- `backend/api/handler/` — the Micronaut Lambda handler
- `cli/` — a command-line client for the same API
- `infra/`, `backend/infra/`, `web-app/infra/` — Terraform, split by concern

### Frontend

A single-page app built with **React**, **Vite**, and **Mantine**. It signs the user in against
**Cognito** (via `oidc-client-ts`), holds the resulting ID token, and calls the backend through a
typed client generated from the OpenAPI contract (`openapi-fetch`). The build is a set of static
assets published to S3 and served through CloudFront, with SPA routing falling back to `index.html`.

### Backend

A **Kotlin + Micronaut** service. The OpenAPI contract is compiled by **Fabrikt** into
request/response models and controller interfaces; the handler implements those interfaces and
exposes three routes — read, increment, decrement — each returning the current count.

The service is built ahead-of-time into a **GraalVM native image** and packaged for a Lambda custom
runtime (`provided.al2023`), so cold starts are in the hundreds of milliseconds. It does no token
work of its own: API Gateway's **Cognito JWT authorizer** validates the caller's token (issuer,
audience, signature, expiry) and rejects anything invalid before the function runs.

### Persistence

The count lives in one row of a **Neon** (serverless Postgres) database, reached through
**SQLDelight** for type-safe queries. SQLDelight owns the schema — an idempotent `CREATE TABLE IF NOT
EXISTS` applied at cold start — so there is no separate migration step for the single table; versioned
`.sqm` migrations can be added when the schema first changes. The connection string is kept in
**Secrets Manager** and read by the function at startup, so the password is never in the function's
plaintext configuration. Local runs and tests swap in an in-memory store.

### Infrastructure

Everything is **Terraform**, split by concern rather than one root module, with state in **S3**:

- `infra/root/shared/` — account-level setup that exists once: the CI/CD role assumed by GitHub
  Actions via OIDC, and the CLI's releases repository
- `infra/root/env-matrix/` — the per-environment identity plane (Cognito user pool, its app clients,
  and the SAML federation to IAM Identity Center), one Terraform workspace per environment
- `backend/infra/foundation/` — the Lambda, API Gateway HTTP API, Cognito JWT authorizer, Neon
  project, the Secrets Manager secret, and the API's custom domain
- `web-app/infra/foundation/` — the S3 bucket, CloudFront distribution, and the web custom domain

Shared values (project name, domains, per-environment hosts) live in `infra/config` and are emitted to
a single `config.json` that every consumer reads, so they stay in sync.

### Delivery

GitHub Actions validate every change and deploy on merge to the trunk branch. Each deploy is phased:
build the artifact once, apply it to **staging**, test staging, then promote the same artifact to
**production** — the phases are chained so a failed staging apply or test stops the promotion. One
workflow covers the native backend, another the SPA.

Environments map to Terraform workspaces of the same name (`prod`, `staging`). The one exception is
`infra/root/shared`, which has no environment dimension and runs in Terraform's `default` workspace.

## Template

This repository doubles as a template. Files carrying a `🎨 TEMPLATE EJECT` marker point to the names
and values a derived project must change — package names, resource names, Terraform state prefixes,
and so on.

To create a derived project, fork the repository and eject:

- visit every `🎨 TEMPLATE EJECT` marker, make the change (mostly renaming), and remove the marker
- then visit every `🎨 TEMPLATE POST-EJECT` marker, perform the manual step it describes, and remove it

<!-- 🎨 TEMPLATE EJECT: Replace this README.md -->
