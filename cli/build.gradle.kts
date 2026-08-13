plugins {
  application

  alias(libs.plugins.kotlin.jvm)
  alias(libs.plugins.kotlin.serialization)
  alias(libs.plugins.shadow)
}

dependencies {
  implementation(libs.clikt)
  implementation(libs.kotlinx.serialization.json)

  // The API client is generated from the OpenAPI contract (Fabrikt, OkHttp target); it
  // (de)serializes
  // with Jackson.
  implementation(libs.okhttp)
  implementation(libs.jackson.module.kotlin)

  testImplementation(libs.kotlin.test)
}

application {
  mainClass = "software.medusa.counter.cli.MainKt"

  // Clikt pulls in JNA (terminal detection); recent JDKs warn on its System.load unless native
  // access is opted in. Keep the installDist launcher quiet (the Homebrew launcher passes the
  // same).
  applicationDefaultJvmArgs = listOf("--enable-native-access=ALL-UNNAMED")
}

tasks.shadowJar {
  archiveBaseName = "counter-cli"
  archiveClassifier = ""
  archiveVersion = ""
  mergeServiceFiles()
}

// Fabrikt runs in its own classpath (JavaExec) rather than as a Gradle plugin: the plugin shares
// the
// buildscript classpath with shadow/jackson, whose versions clash with Fabrikt's own.
val fabrikt: Configuration by configurations.creating

val openApiSpec = rootProject.file("backend/api/openapi/counter.yaml")
val fabriktOut = layout.buildDirectory.dir("generated/fabrikt")

val fabriktGenerate by
    tasks.registering(JavaExec::class) {
      inputs.file(openApiSpec)
      outputs.dir(fabriktOut)
      classpath = fabrikt
      mainClass = "com.cjbooms.fabrikt.cli.CodeGen"
      argumentProviders.add {
        listOf(
            "--api-file",
            openApiSpec.absolutePath,
            "--base-package",
            "software.medusa.counter.cli.api.gen",
            "--output-directory",
            fabriktOut.get().asFile.absolutePath,
            "--targets",
            "http_models",
            "--targets",
            "client",
            "--http-client-target",
            "ok_http",
            "--serialization-library",
            "jackson",
            "--validation-library",
            "no_validation",
        )
      }
      doFirst { fabriktOut.get().asFile.mkdirs() }
    }

kotlin.sourceSets.named("main") { kotlin.srcDir(fabriktOut.map { it.dir("src/main/kotlin") }) }

tasks.named("compileKotlin") { dependsOn(fabriktGenerate) }

// Generated sources live on the compile path but must not be linted/formatted.
tasks.withType<com.ncorti.ktfmt.gradle.tasks.KtfmtBaseTask>().configureEach {
  exclude { it.file.absolutePath.contains("/generated/") }
}

tasks.withType<io.gitlab.arturbosch.detekt.Detekt>().configureEach { exclude("**/generated/**") }

dependencies { fabrikt("com.cjbooms:fabrikt:23.0.0") }
