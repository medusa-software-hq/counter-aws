package software.medusa.counter.cli

import com.github.ajalt.clikt.core.Context
import com.github.ajalt.clikt.core.NoOpCliktCommand
import com.github.ajalt.clikt.core.main
import com.github.ajalt.clikt.core.subcommands
import software.medusa.counter.cli.auth.CognitoTokenProvider
import software.medusa.counter.cli.command.DecrementCommand
import software.medusa.counter.cli.command.GetCommand
import software.medusa.counter.cli.command.IncrementCommand
import software.medusa.counter.cli.command.LoginCommand
import software.medusa.counter.cli.command.LogoutCommand
import software.medusa.counter.cli.config.Environment

class MainCommand : NoOpCliktCommand(name = "ms-counter") {
  override fun help(context: Context) = "Increment, decrement, and read the counter."

  // Read from env vars, not flags (so an invocation can't mix environments); the generated help
  // can't see them, so they're documented here.
  override fun helpEpilog(context: Context) =
      "Environment: ${Environment.ENV_VAR} selects the target — ${Environment.Prod.label} " +
          "(default), ${Environment.Staging.label}, or ${Environment.Local.LABEL} " +
          "(${Environment.Local.LABEL} also needs ${Environment.LOCAL_CONFIG_PATH_ENV} and " +
          "${Environment.LOCAL_PORT_ENV}). ${CognitoTokenProvider.DEV_TOKEN_ENV} sends a bearer " +
          "token instead of signing in."
}

fun main(args: Array<String>) {
  // Each command is self-contained: it resolves the environment, opens its config, and (for API
  // commands) builds the authenticated client — see AppCommand / ManagementCommand.
  MainCommand()
      .subcommands(
          LoginCommand(),
          LogoutCommand(),
          IncrementCommand(),
          DecrementCommand(),
          GetCommand(),
      )
      .main(args)
}
