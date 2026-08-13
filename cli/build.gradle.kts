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

// The per-environment backend host is generated from the resolved config in infra/config — the
// single source shared with Terraform — so the CLI can't drift from the deployed environments.
// Nothing is committed; it regenerates whenever the config changes.
val environmentsConfigFile = rootProject.file("infra/config/config.json")
val generatedEnvironmentsDir = layout.buildDirectory.dir("generated/environments/kotlin")

val generateEnvironments by tasks.registering {
  inputs.file(environmentsConfigFile)
  outputs.dir(generatedEnvironmentsDir)
  doLast {
    @Suppress("UNCHECKED_CAST")
    val config = groovy.json.JsonSlurper().parse(environmentsConfigFile) as Map<String, Any?>

    @Suppress("UNCHECKED_CAST")
    val environments = config["environments"] as Map<String, Map<String, Any?>>

    fun apiHost(env: String): String =
        environments[env]?.get("api_host")?.toString()
            ?: error("config.json is missing environments.$env.api_host")

    val content = buildString {
      appendLine("// Generated from infra/config/config.json — do not edit.")
      appendLine("package software.medusa.counter.cli.config")
      appendLine()
      appendLine("internal object GeneratedEnvironments {")
      appendLine("  const val prodApiHost: String = \"${apiHost("prod")}\"")
      appendLine("  const val stagingApiHost: String = \"${apiHost("staging")}\"")
      appendLine("}")
    }

    val packageDir = generatedEnvironmentsDir.get().dir("software/medusa/counter/cli/config").asFile
    packageDir.mkdirs()
    packageDir.resolve("GeneratedEnvironments.kt").writeText(content)
  }
}

kotlin.sourceSets.named("main") { kotlin.srcDir(generateEnvironments) }

dependencies { fabrikt("com.cjbooms:fabrikt:23.0.0") }
