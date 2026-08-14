package software.medusa.counter.cli.config

import kotlinx.serialization.Serializable

/**
 * A cached Cognito sign-in, persisted (file 0600, dir 0700) via [ConfigStore]. The [idToken] is
 * what the API's JWT authorizer validates; [refreshToken] mints a fresh one when it expires;
 * [expiresAtEpochSeconds] is the id token's `exp`, so the token provider can refresh proactively.
 */
@Serializable
data class Credentials(
    val idToken: String,
    val refreshToken: String,
    val expiresAtEpochSeconds: Long,
)
