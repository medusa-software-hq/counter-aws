package software.medusa.counter.cli.command

import software.medusa.counter.cli.api.CounterApiClient
import software.medusa.counter.cli.auth.CognitoTokenProvider
import software.medusa.counter.cli.config.ConfigStore
import software.medusa.counter.cli.config.Environment

/**
 * Base for commands that talk to the counter API. It attaches the cached Cognito id token when
 * there is one (refreshing it as needed); with no session it sends the request unauthenticated and
 * lets the server decide — the local backend runs open, and prod/staging reject with a 401 the
 * client turns into a "run login" message.
 */
abstract class ManagementCommand(name: String) : AppCommand(name = name) {
  final override fun run(environment: Environment, configStore: ConfigStore) {
    val tokenProvider = CognitoTokenProvider(configStore, environment.cognito)
    CounterApiClient(environment.apiEndpoint, tokenProvider).use { run(it) }
  }

  abstract fun run(apiClient: CounterApiClient)
}
