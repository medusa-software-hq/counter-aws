package software.medusa.counter.cli.config

import java.nio.file.Path

/**
 * Resolves the base state directory shared by every environment: `$XDG_CONFIG_HOME/ms-counter` or,
 * when that is unset, `~/.config/ms-counter` (also on macOS). Each [Environment] then partitions
 * its own subdirectory beneath a resolved base via [Environment.resolveConfigDirPath]. Knowing
 * where the base lives (and the `ms-counter` name) is this object's concern, not an environment's.
 */
object ConfigBaseDir {
  private const val CONFIG_DIR_NAME = "ms-counter"

  fun resolve(
      xdgConfigHome: String?,
      userHome: String,
  ): Path {
    val base =
        if (!xdgConfigHome.isNullOrBlank()) Path.of(xdgConfigHome) else Path.of(userHome, ".config")
    return base.resolve(CONFIG_DIR_NAME)
  }
}
