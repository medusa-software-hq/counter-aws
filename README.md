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

This repository doubles as a template. Files carrying a `🎨 TEMPLATE EJECT` marker point to the names
and values a derived project must change — package names, resource names, Terraform state prefixes,
and so on.

To create a derived project, fork the repository and eject:

- visit every `🎨 TEMPLATE EJECT` marker, make the change (mostly renaming), and remove the marker
- then visit every `🎨 TEMPLATE POST-EJECT` marker, perform the manual step it describes, and remove it

<!-- 🎨 TEMPLATE EJECT: Replace this README.md -->
