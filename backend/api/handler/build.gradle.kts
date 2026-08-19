import io.micronaut.gradle.docker.NativeImageDockerfile

plugins {
  alias(libs.plugins.kotlin.jvm)
  alias(libs.plugins.kotlin.allopen)
  alias(libs.plugins.ksp)
  alias(libs.plugins.micronaut.application)
  alias(libs.plugins.micronaut.aot)
  alias(libs.plugins.sqldelight)
}

// Pin the version so the native-runtime zip has a deterministic name the deploy infra can
// reference.
version = "1.0.0"

// The native binary's entrypoint is selected by `nativeLambda` below; this sets the same v2 runtime
// as the JVM/AOT main class so the non-native build tasks resolve an entrypoint too.
application {
  mainClass = "io.micronaut.function.aws.runtime.APIGatewayV2HTTPEventMicronautLambdaRuntime"
}

dependencies {
  ksp("io.micronaut.serde:micronaut-serde-processor")

  // The custom-runtime event loop polls the Lambda Runtime API over HTTP; the JDK client is the
  // native-image-friendly implementation (no Netty).
  implementation("io.micronaut:micronaut-http-client-jdk")
  implementation("io.micronaut.aws:micronaut-aws-lambda-events-serde")
  implementation("io.micronaut.aws:micronaut-function-aws-api-proxy")
  implementation("io.micronaut.aws:micronaut-function-aws-custom-runtime")
  implementation("io.micronaut.kotlin:micronaut-kotlin-runtime")
  implementation("io.micronaut.serde:micronaut-serde-jackson")

  // Persistence: SQLDelight owns the schema (from the .sq) and generates type-safe queries over its
  // JDBC driver; pgjdbc talks to Neon; the AWS SDK reads the connection string from Secrets
  // Manager.
  // pgjdbc and the SDK ship GraalVM reachability metadata (pgjdbc via the community repository
  // enabled below, the SDK inside its own jars), so native needs no hand-written reflection config.
  implementation(libs.sqldelight.jdbc.driver)
  implementation(libs.postgresql)
  implementation("software.amazon.awssdk:secretsmanager:2.29.52")

  runtimeOnly(libs.logback.classic)
}

// SQLDelight generates a type-safe query layer (CounterDatabase) from the Postgres-dialect .sq; the
// schema it emits (CREATE TABLE IF NOT EXISTS) is applied idempotently at cold start via
// Schema.create. Versioned .sqm migrations can be added at the first schema change.
sqldelight {
  databases {
    create("CounterDatabase") {
      packageName = "software.medusa.counter.db"
      dialect(libs.sqldelight.postgresql.dialect)
    }
  }
}

micronaut {
  runtime("lambda_provided")
  // A Lambda function URL delivers API Gateway HTTP-API payload format 2.0; the default is v1. This
  // selects the v2 custom-runtime entrypoint, which drives the embedded Micronaut router.
  nativeLambda { lambdaRuntime = io.micronaut.gradle.graalvm.NativeLambdaRuntime.API_GATEWAY_V2 }
  testRuntime("junit5")
  processing {
    incremental(true)
    annotations("software.medusa.*")
  }
  aot {
    optimizeServiceLoading = true
    convertYamlToJava = true
    precomputeOperations = true
    cacheEnvironment = true
    optimizeClassLoading = true
    deduceEnvironment = true
    optimizeNetty = true
    replaceLogbackXml = true
  }
}

graalvmNative {
  // Native image is cross-built in Docker (see the deploy workflow), so the local GraalVM toolchain
  // is irrelevant.
  toolchainDetection = false
  // Pull reachability metadata (reflection/resource/JNI config) for third-party libraries — notably
  // the pgjdbc driver — from the GraalVM community repository, keyed by dependency coordinates.
  metadataRepository { enabled = true }
}

tasks.named<NativeImageDockerfile>("dockerfileNative") { jdkVersion = "21" }

// --- Contract-first code generation ------------------------------------------------------------
// Fabrikt runs in its own classpath (JavaExec) rather than as a Gradle plugin: as a plugin it would
// share the buildscript classpath, where a competing Jackson version breaks its YAML parser.
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
            "software.medusa.counter.api",
            "--output-directory",
            fabriktOut.get().asFile.absolutePath,
            "--targets",
            "http_models",
            "--targets",
            "controllers",
            "--http-controller-target",
            "micronaut",
            "--serialization-library",
            "jackson",
            "--http-model-opts",
            "micronaut_introspection",
            "--validation-library",
            "no_validation",
        )
      }
      doFirst { fabriktOut.get().asFile.mkdirs() }
    }

kotlin.sourceSets.named("main") { kotlin.srcDir(fabriktOut.map { it.dir("src/main/kotlin") }) }

// KSP reads the generated sources before compilation, so it (not compileKotlin) is the consumer of
// both generators. KSP registers its task after this script configures, so match it lazily.
tasks
    .matching { it.name == "kspKotlin" }
    .configureEach {
      dependsOn(fabriktGenerate)
      dependsOn(
          tasks.matching { it.name.startsWith("generate") && it.name.contains("CounterDatabase") }
      )
    }

// Generated sources live on the compile path but must not be linted/formatted.
tasks.withType<com.ncorti.ktfmt.gradle.tasks.KtfmtBaseTask>().configureEach {
  exclude { it.file.absolutePath.contains("/generated/") }
}

tasks.withType<io.gitlab.arturbosch.detekt.Detekt>().configureEach { exclude("**/generated/**") }

dependencies { fabrikt("com.cjbooms:fabrikt:23.0.0") }
