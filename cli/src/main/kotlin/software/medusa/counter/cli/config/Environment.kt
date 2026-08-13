package software.medusa.counter.cli.config

import java.nio.file.Path
import software.medusa.counter.cli.api.ApiEndpoint

/**
 * The closed set of environments a single CLI invocation runs against, selected **once** by the
 * `COUNTER_ENVIRONMENT` session property (`AWS_PROFILE`-style — deliberately no per-command flag; a
 * flag would invite mixed-environment command sequences). Absent → [Prod].
 *
 * Each environment is a self-contained bundle of everything a command needs — where its state lives
 * (partitioned, never mixed) and which backend to talk to — so the CLI behaves as N independent
 * instances sharing a binary. The prod/staging backend URLs are deterministic, public,
 * Terraform-computed values kept in sync with `infra/common`'s `environment_config` (the
 * `api.<subdomain_label>.<domain>` host) — mirrored here as source constants.
 */
sealed interface Environment {
  /**
   * Short lowercase name (`prod`/`staging`/`local`); also the state-subdir name for prod/staging.
   */
  val label: String

  /**
   * This environment's private state directory beneath a resolved [baseConfigPath] — never shared.
   * Prod/staging partition by [label]; [Local] uses its own explicit path and ignores the base.
   */
  fun resolveConfigDirPath(baseConfigPath: Path): Path

  /** The one backend endpoint for this environment. */
  val apiEndpoint: ApiEndpoint

  /** The one-line stderr banner a non-prod session prints so a human can't mix environments. */
  val marker: String?

  data object Prod : Environment {
    override val label = "prod"
    override val apiEndpoint = ApiEndpoint("https://${GeneratedEnvironments.prodApiHost}")

    override fun resolveConfigDirPath(baseConfigPath: Path): Path = baseConfigPath.resolve(label)

    override val marker: String? = null
  }

  data object Staging : Environment {
    override val label = "staging"
    override val apiEndpoint = ApiEndpoint("https://${GeneratedEnvironments.stagingApiHost}")

    override fun resolveConfigDirPath(baseConfigPath: Path): Path = baseConfigPath.resolve(label)

    override val marker = "[staging]"
  }

  /**
   * A developer's local backend. Requires an explicit config path (a temp dir in practice, keeping
   * hermetic tests parallel-safe) and port.
   */
  data class Local(private val configDir: Path, val port: Int) : Environment {
    companion object {
      const val LABEL = "local"
    }

    override val label = LABEL
    override val apiEndpoint = ApiEndpoint("http://127.0.0.1:$port")

    override val marker = "[local]"

    /** Local uses its caller-supplied config path directly; the shared base is irrelevant here. */
    override fun resolveConfigDirPath(baseConfigPath: Path): Path = configDir
  }

  companion object {
    const val ENV_VAR = "COUNTER_ENVIRONMENT"
    const val LOCAL_CONFIG_PATH_ENV = "COUNTER_LOCAL_CONFIG_PATH"
    const val LOCAL_PORT_ENV = "COUNTER_API_LOCAL_PORT"

    /**
     * Resolve the environment for this invocation from the `COUNTER_ENVIRONMENT` selector (the
     * caller passes the raw env values). Matching is exact: absent → [Prod], else one of the three
     * labels verbatim; `local` requires both local variables. Anything else, or a misconfigured
     * `local`, raises [EnvironmentSelectionException] for a clean top-level message.
     */
    fun current(raw: String?, localConfigPath: String?, localPort: String?): Environment =
        when (raw) {
          null,
          Prod.label -> Prod
          Staging.label -> Staging
          Local.LABEL -> local(localConfigPath, localPort)
          else ->
              throw EnvironmentSelectionException(
                  "Unknown $ENV_VAR '$raw'. Valid values: ${Prod.label} (default), " +
                      "${Staging.label}, ${Local.LABEL}."
              )
        }

    private fun local(localConfigPath: String?, localPort: String?): Local {
      val path =
          localConfigPath?.ifBlank { null }
              ?: throw EnvironmentSelectionException(
                  "$ENV_VAR=local requires $LOCAL_CONFIG_PATH_ENV to be set to a config directory."
              )
      val portText =
          localPort?.ifBlank { null }
              ?: throw EnvironmentSelectionException(
                  "$ENV_VAR=local requires $LOCAL_PORT_ENV to be set to the local backend's port."
              )
      val port =
          portText.toIntOrNull()?.takeIf { it in 1..65535 }
              ?: throw EnvironmentSelectionException(
                  "$LOCAL_PORT_ENV must be a port number (1–65535), got '$portText'."
              )
      return Local(Path.of(path), port)
    }
  }
}
