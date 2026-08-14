package software.medusa.counter.cli.auth

import java.time.Instant
import software.medusa.counter.cli.config.CognitoConfig
import software.medusa.counter.cli.config.ConfigStore

/**
 * Supplies the id token for API calls from the cached Cognito session, refreshing it when it's
 * within [EXPIRY_SKEW_SECONDS] of expiry. Returns null when there's no usable session (never logged
 * in, or the refresh token was rejected) so the caller can prompt for `login`. A [DEV_TOKEN_ENV]
 * override short-circuits the whole flow for testing or for hitting the API from a build with no
 * baked Cognito config; a transport failure during refresh propagates rather than masquerading as
 * "logged out".
 */
class CognitoTokenProvider(
    private val configStore: ConfigStore,
    private val cognito: CognitoConfig?,
) : TokenProvider {
  override fun provideToken(): String? {
    System.getenv(DEV_TOKEN_ENV)
        ?.ifBlank { null }
        ?.let {
          return it
        }

    val credentials = configStore.loadCredentials() ?: return null
    if (Instant.now().epochSecond < credentials.expiresAtEpochSeconds - EXPIRY_SKEW_SECONDS) {
      return credentials.idToken
    }

    // Near expiry: refresh if this build knows how to reach Cognito. A session can only exist if
    // the
    // config was present at login, so a null config here is the degenerate case — hand back what we
    // have and let the server reject it.
    val cognito = this.cognito ?: return credentials.idToken

    val refreshed =
        try {
          CognitoLogin.refresh(cognito, credentials.refreshToken)
        } catch (e: LoginException) {
          // The refresh token was rejected (expired/revoked); treat it as signed out.
          return null
        }
    configStore.saveCredentials(refreshed)
    return refreshed.idToken
  }

  companion object {
    const val DEV_TOKEN_ENV = "COUNTER_DEV_TOKEN"
    private const val EXPIRY_SKEW_SECONDS = 60L
  }
}
