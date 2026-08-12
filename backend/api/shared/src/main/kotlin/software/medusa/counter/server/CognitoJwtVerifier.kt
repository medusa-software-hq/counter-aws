package software.medusa.counter.server

import com.nimbusds.jose.JOSEException
import com.nimbusds.jose.JWSAlgorithm
import com.nimbusds.jose.proc.BadJOSEException
import com.nimbusds.jose.proc.JWSVerificationKeySelector
import com.nimbusds.jose.proc.SecurityContext
import com.nimbusds.jwt.JWTClaimsSet
import com.nimbusds.jwt.proc.DefaultJWTClaimsVerifier
import com.nimbusds.jwt.proc.DefaultJWTProcessor
import java.text.ParseException

/** Raised when a bearer token is absent, malformed, or fails verification. */
class InvalidTokenException(message: String) : Exception(message)

/**
 * Verifies Cognito ID tokens against a user pool: RS256 signature over the pool's JWKS, exact-match
 * issuer and audience (the app client id), `token_use = id`, and a non-expired `exp`. A verified
 * token is projected to a [CounterPrincipal].
 *
 * The [jwkSource] is injected so tests can supply an in-memory key set; production builds one that
 * fetches and caches the pool's remote JWKS (see [cognitoJwkSource]).
 */
class CognitoJwtVerifier(
    issuer: String,
    audience: String,
    jwkSource: com.nimbusds.jose.jwk.source.JWKSource<SecurityContext>,
) {
  private val processor =
      DefaultJWTProcessor<SecurityContext>().apply {
        jwsKeySelector = JWSVerificationKeySelector(JWSAlgorithm.RS256, jwkSource)
        jwtClaimsSetVerifier =
            DefaultJWTClaimsVerifier(
                JWTClaimsSet.Builder()
                    .issuer(issuer)
                    .audience(audience)
                    .claim(tokenUseClaim, idTokenUse)
                    .build(),
                setOf(emailClaim, "exp"),
            )
      }

  fun verify(token: String): CounterPrincipal {
    val claims =
        try {
          processor.process(token, null)
        } catch (e: ParseException) {
          throw InvalidTokenException("malformed token: ${e.message}")
        } catch (e: BadJOSEException) {
          throw InvalidTokenException("rejected token: ${e.message}")
        } catch (e: JOSEException) {
          throw InvalidTokenException("unverifiable token: ${e.message}")
        }

    return CounterPrincipal(
        email = claims.getStringClaim(emailClaim),
        groups = claims.getStringListClaim(groupsClaim)?.toList() ?: emptyList(),
    )
  }

  private companion object {
    const val emailClaim = "email"
    const val groupsClaim = "cognito:groups"
    const val tokenUseClaim = "token_use"
    const val idTokenUse = "id"
  }
}
