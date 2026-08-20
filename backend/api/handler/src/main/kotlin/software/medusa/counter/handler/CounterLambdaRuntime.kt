package software.medusa.counter.handler

import io.micronaut.context.ApplicationContextBuilder
import io.micronaut.function.aws.runtime.APIGatewayV2HTTPEventMicronautLambdaRuntime
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueRequest

/**
 * The custom runtime's event loop over the API Gateway v2 payload, with the application context
 * configured explicitly and the controller supplied rather than discovered.
 */
class CounterLambdaRuntime(private val controller: CounterController) :
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
          // The controller is supplied, not discovered; its routes still come from the compile-time
          // metadata on the class, but the instance they reach is this one.
          .singletons(controller)
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
  val store = PostgresCounterStore.build(readDatabaseUrl())
  CounterLambdaRuntime(CounterController(store)).run(*args)
}
