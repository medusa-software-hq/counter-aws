package software.medusa.counter.server

import com.linecorp.armeria.common.HttpHeaderNames
import com.linecorp.armeria.common.HttpRequest
import com.linecorp.armeria.common.HttpResponse
import com.linecorp.armeria.common.HttpStatus
import com.linecorp.armeria.server.DecoratingHttpServiceFunction
import com.linecorp.armeria.server.HttpService
import com.linecorp.armeria.server.ServiceRequestContext
import com.nimbusds.jose.jwk.source.JWKSource
import com.nimbusds.jose.jwk.source.JWKSourceBuilder
import com.nimbusds.jose.proc.SecurityContext
import io.netty.util.AttributeKey
import java.net.URI

/**
 * Rejects any request without a valid Cognito bearer token; on success the verified
 * [CounterPrincipal] is attached to the request context under [principalAttr].
 */
class CognitoAuthDecorator(
    private val verifier: CognitoJwtVerifier,
) : DecoratingHttpServiceFunction {
  override fun serve(
      delegate: HttpService,
      ctx: ServiceRequestContext,
      req: HttpRequest,
  ): HttpResponse {
    val header = req.headers().get(HttpHeaderNames.AUTHORIZATION)
    if (header == null || !header.startsWith(bearerPrefix)) {
      return HttpResponse.of(HttpStatus.UNAUTHORIZED)
    }

    val principal =
        try {
          verifier.verify(header.removePrefix(bearerPrefix))
        } catch (e: InvalidTokenException) {
          return HttpResponse.of(HttpStatus.UNAUTHORIZED)
        }

    ctx.setAttr(principalAttr, principal)
    return delegate.serve(ctx, req)
  }

  companion object {
    /** Key under which the verified caller is stored on the request context. */
    val principalAttr: AttributeKey<CounterPrincipal> =
        AttributeKey.valueOf(CognitoAuthDecorator::class.java, "principal")

    private const val bearerPrefix = "Bearer "
  }
}

/**
 * A remote JWK source for a Cognito user pool: fetches `{issuer}/.well-known/jwks.json` and caches
 * it with the library's default refresh, rate-limit, and retry behavior.
 */
fun cognitoJwkSource(issuer: String): JWKSource<SecurityContext> =
    JWKSourceBuilder.create<SecurityContext>(URI("$issuer/.well-known/jwks.json").toURL()).build()
