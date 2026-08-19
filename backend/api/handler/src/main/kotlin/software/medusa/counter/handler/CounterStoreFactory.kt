package software.medusa.counter.handler

import io.micronaut.context.annotation.Factory
import jakarta.inject.Singleton
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueRequest

@Factory
class CounterStoreFactory {
  // Resolve the Neon connection string from the Secrets Manager secret whose ARN the Lambda gets as
  // an env var. Passing the ARN — not the URL — is what keeps the password out of the function's
  // plaintext config.
  @Singleton fun counterStore(): CounterStore = PostgresCounterStore.build(resolveDatabaseUrl())

  private fun resolveDatabaseUrl(): String {
    val secretArn =
        System.getenv("DATABASE_URL_SECRET_ARN") ?: error("DATABASE_URL_SECRET_ARN is not set")
    return SecretsManagerClient.create().use { client ->
      client
          .getSecretValue(GetSecretValueRequest.builder().secretId(secretArn).build())
          .secretString()
    }
  }
}
