package software.medusa.counter.cli.auth

/**
 * Supplies the bearer token to present on an API call, or null when none is configured. The seam
 * the API client attaches to.
 */
interface TokenProvider {
  fun provideToken(): String?
}
