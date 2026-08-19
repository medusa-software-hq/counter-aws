package software.medusa.counter.cli.api

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.module.kotlin.registerKotlinModule
import okhttp3.OkHttpClient
import software.medusa.counter.cli.api.gen.client.ApiClientException
import software.medusa.counter.cli.api.gen.client.ApiException as GeneratedApiException
import software.medusa.counter.cli.api.gen.client.ApiResponse
import software.medusa.counter.cli.api.gen.client.CounterDecrementClient
import software.medusa.counter.cli.api.gen.client.CounterGetClient
import software.medusa.counter.cli.api.gen.client.CounterIncrementClient
import software.medusa.counter.cli.api.gen.client.OAuth2
import software.medusa.counter.cli.api.gen.models.CountReply
import software.medusa.counter.cli.auth.TokenProvider

/**
 * Talks to CounterService over its generated OkHttp REST client. When [tokenProvider] yields a
 * token it is attached as an `Authorization: Bearer` header on every request (the local backend
 * runs open, so a missing token is fine there; prod and staging reject with a 401). The CLI uses
 * one client per command.
 */
class CounterApiClient(endpoint: ApiEndpoint, tokenProvider: TokenProvider) : AutoCloseable {
  private val httpClient: OkHttpClient =
      OkHttpClient.Builder()
          .apply { tokenProvider.provideToken()?.let { token -> addInterceptor(OAuth2 { token }) } }
          .build()

  private val objectMapper: ObjectMapper = ObjectMapper().registerKotlinModule()

  private val getClient = CounterGetClient(objectMapper, endpoint.baseUrl, httpClient)
  private val incrementClient = CounterIncrementClient(objectMapper, endpoint.baseUrl, httpClient)
  private val decrementClient = CounterDecrementClient(objectMapper, endpoint.baseUrl, httpClient)

  fun getCount(): Long = call { getClient.getCount().body() }

  fun increment(): Long = call { incrementClient.incrementCount().body() }

  fun decrement(): Long = call { decrementClient.decrementCount().body() }

  private inline fun <T> call(block: () -> T): T =
      try {
        block()
      } catch (e: GeneratedApiException) {
        throw asApiException(e)
      }

  override fun close() {
    httpClient.dispatcher.executorService.shutdown()
    httpClient.connectionPool.evictAll()
  }

  companion object {
    private fun asApiException(e: GeneratedApiException): ApiException {
      val status = (e as? ApiClientException)?.statusCode
      return when (status) {
        401,
        403 ->
            ApiException(
                "The API rejected your identity ($status). Your session may have lapsed, or your " +
                    "account isn't allowed — try 'ms-counter login' again."
            )
        else -> ApiException("API error: ${e.message}")
      }
    }
  }
}

/** The generated call returns an ApiResponse whose body is present on success. */
private fun ApiResponse<CountReply>.body(): Long =
    data?.count ?: throw ApiException("API returned an empty response.")
