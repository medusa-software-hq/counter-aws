package software.medusa.counter.cli.config

/**
 * What the CLI needs to obtain a token from Cognito: the [issuer] it discovers the OIDC endpoints
 * from, and the public app-client [clientId] it authenticates as. An [Environment] returns null
 * when these weren't baked into the build (they come from per-environment CI variables — see
 * [EnvironmentConfig]), and `login` reports that cleanly.
 */
data class CognitoConfig(
    val issuer: String,
    val clientId: String,
)
