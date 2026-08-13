plugins {
    // Apply the foojay-resolver plugin to allow automatic download of JDKs
    id("org.gradle.toolchains.foojay-resolver-convention") version "0.9.0"
}

rootProject.name = "counter"

include(
    ":backend:api:cloud",
    ":backend:api:local",
    ":backend:api:shared",
    ":backend:api:handler",
    ":cli",
)
