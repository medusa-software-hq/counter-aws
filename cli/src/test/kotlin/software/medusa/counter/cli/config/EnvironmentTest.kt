package software.medusa.counter.cli.config

import java.nio.file.Path
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue
import software.medusa.counter.cli.api.ApiEndpoint

class EnvironmentTest {
  @Test
  fun `absent or prod selects Prod`() {
    assertEquals(
        expected = Environment.Prod,
        actual =
            Environment.current(
                raw = null,
                localConfigPath = null,
                localPort = null,
            ),
    )
    assertEquals(
        expected = Environment.Prod,
        actual =
            Environment.current(
                raw = "prod",
                localConfigPath = null,
                localPort = null,
            ),
    )
  }

  @Test
  fun `staging selects Staging`() {
    assertEquals(
        expected = Environment.Staging,
        actual =
            Environment.current(
                raw = "staging",
                localConfigPath = null,
                localPort = null,
            ),
    )
  }

  @Test
  fun `matching is exact — blanks, case, and aliases are rejected`() {
    assertFailsWith<EnvironmentSelectionException> {
      Environment.current(
          raw = "",
          localConfigPath = null,
          localPort = null,
      )
    }
    assertFailsWith<EnvironmentSelectionException> {
      Environment.current(
          raw = "PROD",
          localConfigPath = null,
          localPort = null,
      )
    }
    assertFailsWith<EnvironmentSelectionException> {
      Environment.current(
          raw = "production",
          localConfigPath = null,
          localPort = null,
      )
    }
    assertFailsWith<EnvironmentSelectionException> {
      Environment.current(
          raw = " staging ",
          localConfigPath = null,
          localPort = null,
      )
    }
    assertFailsWith<EnvironmentSelectionException> {
      Environment.current(
          raw = "prd",
          localConfigPath = null,
          localPort = null,
      )
    }
  }

  @Test
  fun `local requires config path and a valid port`() {
    val env =
        Environment.current(
            raw = "local",
            localConfigPath = "/tmp/x",
            localPort = "8081",
        )
    assertTrue(env is Environment.Local)
    assertEquals(
        expected = ApiEndpoint("http://127.0.0.1:8081"),
        actual = env.apiEndpoint,
    )
    assertFailsWith<EnvironmentSelectionException> {
      Environment.current(
          raw = "local",
          localConfigPath = null,
          localPort = "8081",
      )
    }
    assertFailsWith<EnvironmentSelectionException> {
      Environment.current(
          raw = "local",
          localConfigPath = "/tmp/x",
          localPort = null,
      )
    }
    assertFailsWith<EnvironmentSelectionException> {
      Environment.current(
          raw = "local",
          localConfigPath = "/tmp/x",
          localPort = "nope",
      )
    }
  }

  @Test
  fun `prod and staging are fully partitioned`() {
    val base = Path.of("/base")
    assertEquals(
        expected = Path.of("/base/prod"),
        actual = Environment.Prod.resolveConfigDirPath(baseConfigPath = base),
    )
    assertEquals(
        expected = Path.of("/base/staging"),
        actual = Environment.Staging.resolveConfigDirPath(baseConfigPath = base),
    )
    assertNotEquals(
        illegal = Environment.Prod.resolveConfigDirPath(baseConfigPath = base),
        actual = Environment.Staging.resolveConfigDirPath(baseConfigPath = base),
    )
    assertEquals(
        expected = null,
        actual = Environment.Prod.marker,
    )
    assertEquals(
        expected = "[staging]",
        actual = Environment.Staging.marker,
    )
  }
}
