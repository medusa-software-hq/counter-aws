# Web app

The counter's browser client: a **React** single-page app, built to static files and served through
CloudFront, which signs the user in against Cognito and calls the API on its own origin.

Its REST client is generated from the OpenAPI contract, so the app cannot call an endpoint the
contract does not describe.
