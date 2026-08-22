# API

The counter's service: **Kotlin** on **Micronaut**, implementing controller interfaces generated
from the OpenAPI contract — three routes that read, increment and decrement a single count.

It is compiled ahead of time into a **GraalVM native image** and packaged for a Lambda custom
runtime, so a cold start does not pay for JVM startup. It does no token work of its own: the JWT
authorizer in front rejects anything unsigned, expired or mismatched before the function runs.

The count lives in one row of a **serverless Postgres** database, reached through **SQLDelight**,
which also owns the schema — created idempotently at startup, so there is no separate migration
step. The connection string is read from Secrets Manager when the function starts. Tests swap in an
in-memory store.
