package software.medusa.counter.server

import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient

private const val portEnvVarName = "PORT"
private const val corsOriginRegexEnvVarName = "CORS_ALLOWED_ORIGIN_REGEX"
private const val databaseUrlSecretArnEnvVarName = "DATABASE_URL_SECRET_ARN"
private const val cognitoIssuerEnvVarName = "COGNITO_ISSUER"
private const val cognitoAudienceEnvVarName = "COGNITO_AUDIENCE"

// Lambda has no equivalent of Cloud Run's secret-to-env mapping, so the app
// fetches the Neon connection string from Secrets Manager itself.
private fun fetchDatabaseUrl(secretArn: String): String =
    SecretsManagerClient.create().use { client ->
      client.getSecretValue { it.secretId(secretArn) }.secretString()
    }

fun main() {
  val port =
      System.getenv(portEnvVarName)?.toIntOrNull()
          ?: error("$portEnvVarName environment variable must be set to a valid integer")

  val corsOriginRegex =
      System.getenv(corsOriginRegexEnvVarName)
          ?: error("$corsOriginRegexEnvVarName environment variable must be set")

  val databaseUrl =
      System.getenv(databaseUrlSecretArnEnvVarName)?.let { fetchDatabaseUrl(it) }
          ?: error("$databaseUrlSecretArnEnvVarName environment variable must be set")

  val cognitoIssuer =
      System.getenv(cognitoIssuerEnvVarName)
          ?: error("$cognitoIssuerEnvVarName environment variable must be set")

  val cognitoAudience =
      System.getenv(cognitoAudienceEnvVarName)
          ?: error("$cognitoAudienceEnvVarName environment variable must be set")

  val verifier = CognitoJwtVerifier(cognitoIssuer, cognitoAudience, cognitoJwkSource(cognitoIssuer))

  buildServer(
          originRegex = corsOriginRegex,
          port = port,
          auth = CognitoAuthDecorator(verifier),
          counterStore = PostgresCounterStore.build(databaseUrl),
      )
      .start()
      .join()
}
