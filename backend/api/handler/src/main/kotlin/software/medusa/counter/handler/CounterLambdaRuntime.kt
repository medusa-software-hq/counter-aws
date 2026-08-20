package software.medusa.counter.handler

import io.micronaut.context.ApplicationContextBuilder
import io.micronaut.function.aws.runtime.APIGatewayV2HTTPEventMicronautLambdaRuntime
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueRequest

/**
 * The custom runtime's event loop over the API Gateway v2 payload, with the application context
 * configured explicitly: the store is built here and handed in, rather than discovered.
 */
class CounterLambdaRuntime(private val store: CounterStore) :
    APIGatewayV2HTTPEventMicronautLambdaRuntime() {

  override fun createApplicationContextBuilderWithArgs(
      vararg args: String
  ): ApplicationContextBuilder =
      super.createApplicationContextBuilderWithArgs(*args)
          .banner(false)
          // Probing instance-metadata endpoints costs cold-start latency to discover a cloud we
          // already know we are running in.
          .deduceCloudEnvironment(false)
          // Build what the context needs during initialization, so a broken configuration fails the
          // cold start rather than whichever request arrives first.
          .eagerInitSingletons(true)
          .singletons(store)
}

/** The connection string, from the Secrets Manager secret whose ARN the function is given. */
private fun readDatabaseUrl(): String {
  val secretArn =
      System.getenv("DATABASE_URL_SECRET_ARN") ?: error("DATABASE_URL_SECRET_ARN is not set")
  return SecretsManagerClient.create().use { client ->
    client
        .getSecretValue(GetSecretValueRequest.builder().secretId(secretArn).build())
        .secretString()
  }
}

fun main(args: Array<String>) {
  CounterLambdaRuntime(PostgresCounterStore.build(readDatabaseUrl())).run(*args)
}
