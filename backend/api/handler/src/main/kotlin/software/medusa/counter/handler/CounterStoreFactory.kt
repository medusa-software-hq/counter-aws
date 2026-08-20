package software.medusa.counter.handler

import io.micronaut.context.annotation.Factory
import jakarta.inject.Singleton
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueRequest

@Factory
class CounterStoreFactory {
  @Singleton fun counterStore(): CounterStore = PostgresCounterStore.build(resolveDatabaseUrl())

  /**
   * Reads the database connection string at startup. The function is handed the secret's ARN rather
   * than the string, so the password never sits in its plaintext configuration.
   */
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
