package software.medusa.counter.cli.config

import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.attribute.PosixFilePermissions
import kotlinx.serialization.json.Json

/**
 * All persisted per-environment state under a single environment's config directory — currently
 * just the cached sign-in ([Credentials]); this is the one place that reads or writes the config
 * directory, so its file layout and on-disk permissions live in exactly one spot.
 *
 * The token inside [Credentials] is the sensitive bit, so the file is written 0600 and the
 * directory created 0700, set atomically at creation where the platform supports POSIX permissions.
 * [dir] is the environment's partitioned config directory; there is no ambient default, so a prod
 * and a staging session can never share a file.
 */
class ConfigStore(private val dir: Path) {
  private val credentialsFile: Path = dir.resolve(CREDENTIALS_FILE_NAME)

  fun loadCredentials(): Credentials? {
    if (!Files.exists(credentialsFile)) return null
    return json.decodeFromString(Files.readString(credentialsFile))
  }

  /**
   * Writes [credentials] with dir 0700 / file 0600, set atomically at creation. Only a platform
   * without POSIX permissions (Windows) falls back to default attributes; every other failure
   * propagates, because a token file silently created world-readable is worse than a failed save.
   */
  fun saveCredentials(credentials: Credentials) {
    if (!Files.exists(dir)) {
      // The parents are ordinary config directories; only the leaf holds the token.
      dir.parent?.let { Files.createDirectories(it) }
      try {
        Files.createDirectory(dir, DIR_PERMISSIONS)
      } catch (unsupported: UnsupportedOperationException) {
        Files.createDirectory(dir)
      }
    }
    Files.deleteIfExists(credentialsFile)
    try {
      Files.createFile(credentialsFile, FILE_PERMISSIONS)
    } catch (unsupported: UnsupportedOperationException) {
      Files.createFile(credentialsFile)
    }
    Files.writeString(credentialsFile, json.encodeToString(credentials))
  }

  fun deleteCredentials() {
    Files.deleteIfExists(credentialsFile)
  }

  companion object {
    private const val CREDENTIALS_FILE_NAME = "credentials.json"

    private val json = Json {
      ignoreUnknownKeys = true
      prettyPrint = true
    }

    private val DIR_PERMISSIONS =
        PosixFilePermissions.asFileAttribute(PosixFilePermissions.fromString("rwx------"))
    private val FILE_PERMISSIONS =
        PosixFilePermissions.asFileAttribute(PosixFilePermissions.fromString("rw-------"))
  }
}
