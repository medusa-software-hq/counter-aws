# `ms-counter` — the Counter CLI

A small Kotlin/JVM command-line client for the Counter service. It signs you in
with your `medusa.software` identity and drives the counter from a terminal.

```
ms-counter login        # sign in (opens a browser) and cache the session
ms-counter increment    # +1, prints the new count
ms-counter decrement    # -1, prints the new count
ms-counter get          # print the current count
ms-counter logout       # forget the cached session on this machine
```

## Install (Homebrew)

```
brew install medusa-software-hq/tap/counter-aws
```

It depends on `openjdk@21` (installed automatically) and runs as `ms-counter`.

## How auth works

`login` runs authorization code + PKCE against this environment's Cognito user
pool, which federates to IAM Identity Center over SAML. It opens your browser to
the Hosted UI and catches the redirect on a **fixed** `127.0.0.1:51789` loopback —
fixed rather than ephemeral because Cognito matches callback URLs exactly. The app
client is public: there is no client secret. It caches a refresh token under this
environment's config dir (dir `0700`, file `0600`) and silently refreshes the
short-lived ID token as needed — you only re-`login` if the refresh token is
revoked.

Each request sends your Cognito **ID token** as `Authorization: Bearer …`. API
Gateway's JWT authorizer validates it — issuer (the user pool) and audience (this
environment's app clients) — and rejects anything unsigned, expired, or mismatched
before the function runs.

## Environments

The CLI runs against **one environment per invocation**, chosen once by
`COUNTER_ENVIRONMENT` (`AWS_PROFILE`-style — no per-command flag). Absent → prod.
Each environment has its **own** partitioned session under
`~/.config/ms-counter/<env>/`, its own backend, and its own Cognito user pool and
app client, so prod and staging can never share credentials. Non-prod prints a dim marker
(`[staging]`) to stderr.

```
ms-counter increment                              # prod (default)
COUNTER_ENVIRONMENT=staging ms-counter increment  # staging
```

## Local development

Point the CLI at a local backend with `COUNTER_ENVIRONMENT=local`, supplying the
config dir and port:

```
COUNTER_ENVIRONMENT=local \
COUNTER_LOCAL_CONFIG_PATH=/tmp/ms-counter-local \
COUNTER_API_LOCAL_PORT=8081 \
  ms-counter get
```

The local backend uses no-op auth, so `get`/`increment`/`decrement` work without
`login` (the CLI still attaches a token; the no-op decorator ignores it). Sign-in
is public PKCE — no client secret — but a dev build bakes no Cognito config, so
`login` against a real environment only works if you build with that
environment's values (`COGNITO_ISSUER_URL_PROD` + `COGNITO_CLI_CLIENT_ID_PROD`,
or the `_STAGING` pair); the published CLI has them baked. To call a real API
from a dev build without signing in, set `COUNTER_DEV_TOKEN` to a token you hold.

Common tasks (via [Task](https://taskfile.dev)):

```
task cli:build         # compile
task cli:test          # unit tests
task cli:lint          # detekt
task cli:run -- get    # build + run locally
```
