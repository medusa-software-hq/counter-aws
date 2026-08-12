package software.medusa.counter.server

/** The authenticated caller, projected from a verified Cognito ID token. */
data class CounterPrincipal(
    val email: String,
    val groups: List<String>,
)
