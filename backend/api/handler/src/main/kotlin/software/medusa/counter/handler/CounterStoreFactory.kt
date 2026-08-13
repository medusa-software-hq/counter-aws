package software.medusa.counter.handler

import io.micronaut.context.annotation.Factory
import jakarta.inject.Singleton
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueRequest

@Factory
class CounterStoreFactory {
  // Resolve the Neon connection string: a plaintext env var when set (local RIE runs), otherwise
  // the
  // Secrets Manager secret whose ARN the Lambda gets as an env var. Passing the ARN — not the URL —
  // is what keeps the password out of the function's plaintext config.
  @Singleton fun counterStore(): CounterStore = PostgresCounterStore.build(resolveDatabaseUrl())

  private fun resolveDatabaseUrl(): String {
    System.getenv("COUNTER_DATABASE_URL")?.let {
      return it
    }
    val secretArn =
        System.getenv("DATABASE_URL_SECRET_ARN")
            ?: error("neither COUNTER_DATABASE_URL nor DATABASE_URL_SECRET_ARN is set")
    return SecretsManagerClient.create().use { client ->
      client
          .getSecretValue(GetSecretValueRequest.builder().secretId(secretArn).build())
          .secretString()
    }
  }
}
