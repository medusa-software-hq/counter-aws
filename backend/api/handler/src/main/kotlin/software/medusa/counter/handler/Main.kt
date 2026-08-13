package software.medusa.counter.handler

import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import software.medusa.counter.api.models.CountReply

/** The subset of the Lambda function-URL / API Gateway v2 response we emit. */
@Serializable
private data class LambdaHttpResponse(
    val statusCode: Int,
    val headers: Map<String, String>,
    val body: String,
)

private val json = Json { encodeDefaults = true }

/**
 * Custom-runtime entrypoint: polls the Lambda Runtime API and answers each invocation. This spike
 * ignores the request and returns a fixed count — just enough to prove a GraalVM-native binary
 * serves on Lambda.
 */
fun main() {
  val api = System.getenv("AWS_LAMBDA_RUNTIME_API") ?: error("AWS_LAMBDA_RUNTIME_API not set")
  val base = "http://$api/2018-06-01/runtime"
  val http = HttpClient.newHttpClient()

  while (true) {
    val next =
        http.send(
            HttpRequest.newBuilder(URI("$base/invocation/next")).GET().build(),
            HttpResponse.BodyHandlers.ofString(),
        )
    val requestId = next.headers().firstValue("Lambda-Runtime-Aws-Request-Id").orElse("")

    val reply = LambdaHttpResponse(
        statusCode = 200,
        headers = mapOf("content-type" to "application/json"),
        body = json.encodeToString(CountReply.serializer(), CountReply(count = 42)),
    )

    http.send(
        HttpRequest.newBuilder(URI("$base/invocation/$requestId/response"))
            .POST(HttpRequest.BodyPublishers.ofString(json.encodeToString(LambdaHttpResponse.serializer(), reply)))
            .build(),
        HttpResponse.BodyHandlers.discarding(),
    )
  }
}
