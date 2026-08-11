plugins {
  alias(libs.plugins.jib)
  alias(libs.plugins.kotlin.jvm)

  application
}

val javaVersion = 21
val containerPort = 8080
val containerImageRef = findProperty("jib.imageRef")?.toString() ?: "api"
val containerImageTag = findProperty("jib.imageTag")?.toString() ?: "local"

dependencies {
  implementation(project(":backend:api:shared"))

  // Reads the DB connection string from AWS Secrets Manager on Lambda (Lambda
  // has no equivalent of Cloud Run's secret-to-env mapping).
  implementation(libs.awssdk.secretsmanager)
}

application { mainClass = "software.medusa.counter.server.MainKt" }

jib {
  // glibc base (not alpine): most compatible with the AWS Lambda Web Adapter
  // binary the deploy workflow drops into src/main/jib/opt/extensions/.
  from { image = "eclipse-temurin:$javaVersion-jre" }

  to {
    image = containerImageRef
    tags = setOf(containerImageTag)
  }

  container {
    ports = listOf(containerPort.toString())
    mainClass = "software.medusa.counter.server.MainKt"
  }

  // The Lambda Web Adapter runs as a Lambda extension; it must be executable.
  // The binary itself is provided at build time under src/main/jib (git-ignored),
  // extracted from the official image by the deploy workflow.
  extraDirectories { permissions = mapOf("/opt/extensions/lambda-adapter" to "755") }
}
