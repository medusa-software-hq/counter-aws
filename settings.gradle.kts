plugins {
    // Lets Gradle fetch a matching JDK instead of requiring one preinstalled.
    id("org.gradle.toolchains.foojay-resolver-convention") version "0.9.0"
}

rootProject.name = "counter"

include(
    ":backend:api:handler",
    ":cli",
)
