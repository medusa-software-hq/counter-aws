package software.medusa.counter.cli.auth

/**
 * A sign-in that failed for a reason worth showing the user (denied, timed out, protocol error).
 */
class LoginException(message: String) : Exception(message)
