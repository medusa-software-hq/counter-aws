package software.medusa.counter.server

import com.nimbusds.jose.JWSAlgorithm
import com.nimbusds.jose.JWSHeader
import com.nimbusds.jose.crypto.RSASSASigner
import com.nimbusds.jose.jwk.JWKSet
import com.nimbusds.jose.jwk.RSAKey
import com.nimbusds.jose.jwk.gen.RSAKeyGenerator
import com.nimbusds.jose.jwk.source.ImmutableJWKSet
import com.nimbusds.jose.proc.SecurityContext
import com.nimbusds.jwt.JWTClaimsSet
import com.nimbusds.jwt.SignedJWT
import java.time.Instant
import java.util.Date
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class CognitoJwtVerifierTest {
  private val issuer = "https://cognito-idp.eu-central-1.amazonaws.com/eu-central-1_VAwtyuzD9"
  private val audience = "6c8laruvc33dqj0rm6a91cn8p8"
  private val signingKey = RSAKeyGenerator(2048).keyID("test-key").generate()

  private fun verifier(key: RSAKey = signingKey) =
      CognitoJwtVerifier(
          issuer = issuer,
          audience = audience,
          jwkSource = ImmutableJWKSet<SecurityContext>(JWKSet(key.toPublicJWK())),
      )

  private fun mint(
      key: RSAKey = signingKey,
      issuer: String = this.issuer,
      audience: String = this.audience,
      tokenUse: String? = "id",
      email: String? = "user@medusa.software",
      groups: List<String>? = listOf("Devs", "counter-users"),
      expiresAt: Instant = Instant.now().plusSeconds(300),
  ): String {
    val claims =
        JWTClaimsSet.Builder()
            .issuer(issuer)
            .audience(audience)
            .subject("sub-123")
            .expirationTime(Date.from(expiresAt))
            .apply {
              tokenUse?.let { claim("token_use", it) }
              email?.let { claim("email", it) }
              groups?.let { claim("cognito:groups", it) }
            }
            .build()
    val jwt = SignedJWT(JWSHeader.Builder(JWSAlgorithm.RS256).keyID(key.keyID).build(), claims)
    jwt.sign(RSASSASigner(key))
    return jwt.serialize()
  }

  @Test
  fun `accepts a valid id token and projects email and groups`() {
    val principal = verifier().verify(mint())

    assertEquals("user@medusa.software", principal.email)
    assertEquals(listOf("Devs", "counter-users"), principal.groups)
  }

  @Test
  fun `treats a missing groups claim as no groups`() {
    val principal = verifier().verify(mint(groups = null))

    assertEquals(emptyList(), principal.groups)
  }

  @Test
  fun `rejects a foreign audience`() {
    assertFailsWith<InvalidTokenException> {
      verifier().verify(mint(audience = "some-other-client-id"))
    }
  }

  @Test
  fun `rejects a wrong issuer`() {
    assertFailsWith<InvalidTokenException> {
      verifier().verify(mint(issuer = "https://accounts.google.com"))
    }
  }

  @Test
  fun `rejects an expired token`() {
    assertFailsWith<InvalidTokenException> {
      verifier().verify(mint(expiresAt = Instant.now().minusSeconds(3600)))
    }
  }

  @Test
  fun `rejects a token signed by an unknown key`() {
    val foreignKey = RSAKeyGenerator(2048).keyID("test-key").generate()

    assertFailsWith<InvalidTokenException> { verifier().verify(mint(key = foreignKey)) }
  }

  @Test
  fun `rejects an access token (token_use != id)`() {
    assertFailsWith<InvalidTokenException> { verifier().verify(mint(tokenUse = "access")) }
  }

  @Test
  fun `rejects a token missing the email claim`() {
    assertFailsWith<InvalidTokenException> { verifier().verify(mint(email = null)) }
  }

  @Test
  fun `rejects a malformed token`() {
    assertFailsWith<InvalidTokenException> { verifier().verify("not-a-jwt") }
  }
}
