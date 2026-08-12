package software.medusa.counter.server

import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient

private const val portEnvVarName = "PORT"
private const val corsOriginRegexEnvVarName = "CORS_ALLOWED_ORIGIN_REGEX"
private const val databaseUrlSecretArnEnvVarName = "DATABASE_URL_SECRET_ARN"

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

  // No real authentication yet: the identity provider is mid-migration, so this runs a pass-through
  // gate. The service is kept private upstream until a JWT verifier is wired in.
  buildServer(
          originRegex = corsOriginRegex,
          port = port,
          auth = NoOpAuthDecorator,
          counterStore = PostgresCounterStore.build(databaseUrl),
      )
      .start()
      .join()
}
