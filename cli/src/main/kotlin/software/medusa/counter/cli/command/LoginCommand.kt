package software.medusa.counter.cli.command

import com.github.ajalt.clikt.core.Context
import com.github.ajalt.clikt.core.PrintMessage
import software.medusa.counter.cli.auth.CognitoLogin
import software.medusa.counter.cli.auth.LoginException
import software.medusa.counter.cli.config.ConfigStore
import software.medusa.counter.cli.config.Environment

/**
 * `login` — sign in through the browser (Cognito, authorization code + PKCE) and cache the session.
 */
class LoginCommand : AppCommand(name = "login") {
  override fun help(context: Context) = "Sign in through your browser."

  override fun run(environment: Environment, configStore: ConfigStore) {
    val cognito =
        environment.cognito
            ?: throw PrintMessage(
                "Sign-in isn't available for the ${environment.label} environment in this build.",
                statusCode = 2,
                printError = true,
            )

    val credentials =
        try {
          CognitoLogin.authenticate(cognito) { echo(it) }
        } catch (e: LoginException) {
          throw PrintMessage(e.message ?: "Sign-in failed.", statusCode = 1, printError = true)
        }

    configStore.saveCredentials(credentials)
    echo("Signed in to the ${environment.label} environment.")
  }
}
