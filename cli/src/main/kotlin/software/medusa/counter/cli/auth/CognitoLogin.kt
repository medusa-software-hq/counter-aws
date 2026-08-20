package software.medusa.counter.cli.auth

import com.nimbusds.jwt.JWT
import com.nimbusds.oauth2.sdk.AuthorizationCode
import com.nimbusds.oauth2.sdk.AuthorizationCodeGrant
import com.nimbusds.oauth2.sdk.RefreshTokenGrant
import com.nimbusds.oauth2.sdk.ResponseType
import com.nimbusds.oauth2.sdk.Scope
import com.nimbusds.oauth2.sdk.TokenRequest
import com.nimbusds.oauth2.sdk.id.ClientID
import com.nimbusds.oauth2.sdk.id.Issuer
import com.nimbusds.oauth2.sdk.id.State
import com.nimbusds.oauth2.sdk.pkce.CodeChallengeMethod
import com.nimbusds.oauth2.sdk.pkce.CodeVerifier
import com.nimbusds.oauth2.sdk.token.RefreshToken
import com.nimbusds.openid.connect.sdk.AuthenticationRequest
import com.nimbusds.openid.connect.sdk.OIDCTokenResponse
import com.nimbusds.openid.connect.sdk.OIDCTokenResponseParser
import com.nimbusds.openid.connect.sdk.op.OIDCProviderMetadata
import com.nimbusds.openid.connect.sdk.token.OIDCTokens
import java.awt.Desktop
import java.net.URI
import java.time.Duration
import software.medusa.counter.cli.config.CognitoConfig
import software.medusa.counter.cli.config.Credentials

/**
 * The CLI's Cognito sign-in: OAuth 2.0 authorization code + PKCE with a loopback redirect (RFC
 * 8252). Cognito has no device-authorization grant, so [authenticate] opens a browser to the Hosted
 * UI and catches the redirect on the fixed local port the app-client registers, then exchanges the
 * code for tokens. [refresh] renews an expired id token from a stored refresh token. Both discover
 * the OAuth endpoints from the issuer, so only the issuer + client id need to be known ahead of
 * time.
 */
object CognitoLogin {
  private const val REDIRECT_PORT = 51789
  private const val REDIRECT_PATH = "/callback"
  private const val REDIRECT_URI = "http://localhost:$REDIRECT_PORT$REDIRECT_PATH"
  private val SCOPE = Scope("openid", "email", "profile")
  private val LOGIN_TIMEOUT: Duration = Duration.ofMinutes(5)

  fun authenticate(cognito: CognitoConfig, echo: (String) -> Unit): Credentials {
    val metadata = discover(cognito.issuer)
    val clientId = ClientID(cognito.clientId)
    val redirectUri = URI(REDIRECT_URI)
    val verifier = CodeVerifier()
    val state = State()

    val authRequest =
        AuthenticationRequest.Builder(ResponseType("code"), SCOPE, clientId, redirectUri)
            .endpointURI(metadata.authorizationEndpointURI)
            .state(state)
            .codeChallenge(verifier, CodeChallengeMethod.S256)
            .build()

    CallbackServer(REDIRECT_PORT, REDIRECT_PATH).use { server ->
      echo(
          "Opening your browser to sign in. If it doesn't open, visit:\n\n  ${authRequest.toURI()}\n"
      )
      openBrowser(authRequest.toURI())

      val callback = server.awaitCallback(LOGIN_TIMEOUT)
      if (callback["state"] != state.value) {
        throw LoginException("Sign-in failed: state mismatch (possible CSRF). Please try again.")
      }
      callback["error"]?.let { error ->
        val description = callback["error_description"]?.let { " ($it)" }.orEmpty()
        throw LoginException("Sign-in was denied or failed: $error$description.")
      }
      val code =
          callback["code"]
              ?: throw LoginException("Sign-in failed: no authorization code returned.")

      val tokens =
          exchange(
              TokenRequest.Builder(
                      metadata.tokenEndpointURI,
                      clientId,
                      AuthorizationCodeGrant(AuthorizationCode(code), redirectUri, verifier),
                  )
                  .build()
          )
      return credentialsFrom(tokens, fallbackRefreshToken = null)
    }
  }

  fun refresh(cognito: CognitoConfig, refreshToken: String): Credentials {
    val metadata = discover(cognito.issuer)
    val tokens =
        exchange(
            TokenRequest.Builder(
                    metadata.tokenEndpointURI,
                    ClientID(cognito.clientId),
                    RefreshTokenGrant(RefreshToken(refreshToken)),
                )
                .build()
        )
    // Cognito doesn't rotate the refresh token, so carry the existing one forward.
    return credentialsFrom(tokens, fallbackRefreshToken = refreshToken)
  }

  private fun discover(issuer: String): OIDCProviderMetadata =
      OIDCProviderMetadata.resolve(Issuer(issuer))

  /**
   * Sends a token request; throws [LoginException] on an OAuth error, IOException on a transport
   * one.
   */
  private fun exchange(request: TokenRequest): OIDCTokens {
    val response = OIDCTokenResponseParser.parse(request.toHTTPRequest().send())
    if (!response.indicatesSuccess()) {
      val error = response.toErrorResponse().errorObject
      throw LoginException(
          "Token request rejected: ${error.code} ${error.description.orEmpty()}".trim()
      )
    }
    return (response as OIDCTokenResponse).oidcTokens
  }

  private fun credentialsFrom(tokens: OIDCTokens, fallbackRefreshToken: String?): Credentials {
    val idToken: JWT = tokens.idToken
    val expiresAt = idToken.jwtClaimsSet.expirationTime.toInstant().epochSecond
    val refreshToken =
        tokens.refreshToken?.value
            ?: fallbackRefreshToken
            ?: throw LoginException("Cognito did not return a refresh token.")
    return Credentials(tokens.idTokenString, refreshToken, expiresAt)
  }

  /**
   * Best effort. The sign-in URL is printed first either way, so a headless host can copy it, and a
   * failure to open is swallowed rather than aborting the login.
   */
  private fun openBrowser(uri: URI) {
    runCatching {
      if (Desktop.isDesktopSupported() && Desktop.getDesktop().isSupported(Desktop.Action.BROWSE)) {
        Desktop.getDesktop().browse(uri)
        return
      }
    }
    val command =
        System.getProperty("os.name").lowercase().let { os ->
          when {
            "mac" in os -> listOf("open", uri.toString())
            "win" in os -> listOf("rundll32", "url.dll,FileProtocolHandler", uri.toString())
            else -> listOf("xdg-open", uri.toString())
          }
        }
    runCatching { ProcessBuilder(command).start() }
  }
}
