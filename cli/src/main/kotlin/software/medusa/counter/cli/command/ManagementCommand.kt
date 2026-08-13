package software.medusa.counter.cli.command

import software.medusa.counter.cli.api.ApiException
import software.medusa.counter.cli.api.CounterApiClient
import software.medusa.counter.cli.auth.DevTokenProvider
import software.medusa.counter.cli.config.ConfigStore
import software.medusa.counter.cli.config.Environment

/**
 * Base for commands that talk to the counter API. The API now requires a signed-in Cognito
 * identity; the CLI has no login flow yet, so unless a token is supplied out-of-band it fails fast
 * with a clear message rather than issuing a doomed request that only 401s.
 */
abstract class ManagementCommand(name: String) : AppCommand(name = name) {
  final override fun run(environment: Environment, configStore: ConfigStore) {
    val tokenProvider = DevTokenProvider(configStore)
    if (tokenProvider.provideToken() == null) {
      throw ApiException(
          "The counter API now requires a signed-in identity, and the CLI can't obtain one yet " +
              "(Cognito login for the CLI is not implemented). Sign in through the web app, or set " +
              "a valid ID token in ${DevTokenProvider.DEV_TOKEN_ENV} to call the API meanwhile."
      )
    }
    CounterApiClient(environment.apiEndpoint, tokenProvider).use { run(it) }
  }

  abstract fun run(apiClient: CounterApiClient)
}
