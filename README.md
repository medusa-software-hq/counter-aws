# Counter

An experimental internal project — a small full-stack "counter" app that doubles as a template for
other internal services. This variant runs entirely on **AWS**, serverless.

## What it is

A web app with an API behind it, behind **Cognito** sign-in federated to IAM Identity Center. A
command-line client drives the same API.

Both sides of that API are generated from one OpenAPI contract, so the client and the server cannot
drift apart — a change to the contract breaks whichever side did not follow it.

At runtime:

```text
Browser
  -> the web app, static files served through CloudFront
  -> Cognito Hosted UI for sign-in (OIDC)
  -> CloudFront routes /api to API Gateway
  -> Cognito JWT authorizer validates the ID token
  -> the API, on Lambda
  -> serverless Postgres
```

The web app and the API share an origin, so the browser never makes a cross-origin request and
there is no CORS to configure. Nothing in the API does token work of its own: an unauthenticated
request is rejected before it reaches any code we wrote.

## Environments

Production and staging, identical in shape and isolated from one another — their own user pools,
their own data, their own hosts. A deploy builds once, applies to staging, checks it, and only then
promotes the same artifact to production, so a failure stops short of production.

## Template

This repository doubles as a template for other internal services. A derived project is generated
from it, then *ejected* — given its own name, its own resources, and its own Terraform state.

Two kinds of marker say what an eject has to change. They differ in where the value comes from:

- `🎨 TEMPLATE EJECT` — a value chosen up front, so every one of them can be filled in before
  anything is created.
- `🎨 TEMPLATE BOOTSTRAP` — a value that does not exist until something is created outside
  Terraform, so it can only be filled in once that thing exists.

What identifies the *organization* rather than the project — the domain, the GitHub org, the AWS
account — is not marked: a derived project inherits it. Neither is the application's own name, which
is found by searching for it rather than by marker, and which a derived project replaces anyway.

Ejecting, in order:

1. Generate a repository from this template, and set its default branch.
2. Make every `🎨 TEMPLATE EJECT` change, and remove the marker.
3. Apply the repository configuration, then the shared infrastructure.
4. Create the releaser GitHub App; install it on this repository, on the releases repository, and on
   the shared Homebrew tap.
5. Per environment, apply the identity plane far enough to create the user pool, create that pool's
   IdC SAML application from its ACS URL and audience, then apply the environment in full. Each half
   needs the other's output, so this pass cannot be collapsed into one.
6. Push to the trunk branch, and the deploy workflows apply the rest.

<!-- 🎨 TEMPLATE EJECT: Replace this README.md -->
