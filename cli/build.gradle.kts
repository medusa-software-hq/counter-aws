plugins {
  application

  alias(libs.plugins.kotlin.jvm)
  alias(libs.plugins.kotlin.serialization)
  alias(libs.plugins.shadow)
}

dependencies {
  implementation(libs.clikt)
  implementation(libs.kotlinx.serialization.json)

  // OAuth 2.0 / OIDC for the Cognito sign-in (authorization code + PKCE, endpoint discovery). Don't
  // hand-roll the protocol.
  implementation("com.nimbusds:oauth2-oidc-sdk:11.21")

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

// The per-environment backend host is generated from the committed deployment config — the
// single source shared with Terraform — so the CLI can't drift from the deployed environments.
// Nothing is committed; it regenerates whenever the config changes.
val environmentsConfigFile = rootProject.file("infra/config/config.json")
val generatedEnvironmentsDir = layout.buildDirectory.dir("generated/environments/kotlin")

// The API host is author-derived, so it comes from the committed config.json. The Cognito issuer +
// client id are Cognito-generated (they only exist after root infra applies), so they're baked from
// per-environment build variables, suffixed `_PROD`/`_STAGING` (symmetric — prod is not the
// unsuffixed default). The publish workflow reads each environment's `COGNITO_*` and maps them
// here,
// so the published CLI can log in to either. Unset (a local build) → empty → login reports that
// environment as unavailable.
val cognitoValues =
    mapOf(
        "prodCognitoIssuer" to providers.environmentVariable("COGNITO_ISSUER_URL_PROD").orElse(""),
        "prodCognitoClientId" to
            providers.environmentVariable("COGNITO_CLI_CLIENT_ID_PROD").orElse(""),
        "stagingCognitoIssuer" to
            providers.environmentVariable("COGNITO_ISSUER_URL_STAGING").orElse(""),
        "stagingCognitoClientId" to
            providers.environmentVariable("COGNITO_CLI_CLIENT_ID_STAGING").orElse(""),
    )

val generateEnvironments by tasks.registering {
  inputs.file(environmentsConfigFile)
  cognitoValues.forEach { (name, value) -> inputs.property(name, value) }
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
      appendLine(
          "// Generated from infra/config/config.json + the COGNITO_* CI variables — do not edit."
      )
      appendLine("package software.medusa.counter.cli.config")
      appendLine()
      appendLine("internal sealed interface EnvironmentConfig {")
      appendLine("  val apiHost: String")
      appendLine("  val cognitoIssuer: String")
      appendLine("  val cognitoClientId: String")
      listOf("prod" to "Prod", "staging" to "Staging").forEach { (env, obj) ->
        appendLine()
        appendLine("  object $obj : EnvironmentConfig {")
        appendLine("    override val apiHost: String = \"${apiHost(env)}\"")
        appendLine(
            "    override val cognitoIssuer: String = \"${cognitoValues.getValue("${env}CognitoIssuer").get()}\""
        )
        appendLine(
            "    override val cognitoClientId: String = \"${cognitoValues.getValue("${env}CognitoClientId").get()}\""
        )
        appendLine("  }")
      }
      appendLine("}")
    }

    val packageDir = generatedEnvironmentsDir.get().dir("software/medusa/counter/cli/config").asFile
    packageDir.mkdirs()
    packageDir.resolve("EnvironmentConfig.kt").writeText(content)
  }
}

kotlin.sourceSets.named("main") { kotlin.srcDir(generateEnvironments) }

dependencies { fabrikt("com.cjbooms:fabrikt:23.0.0") }
