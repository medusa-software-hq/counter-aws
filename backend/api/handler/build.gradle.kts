plugins {
  alias(libs.plugins.kotlin.jvm)
  alias(libs.plugins.kotlin.serialization)
}

// Fabrikt runs in its own classpath (JavaExec) rather than as a Gradle plugin: the
// plugin shares the buildscript classpath with jib/protobuf, whose older Jackson
// breaks Fabrikt's YAML parser. Isolated, it pulls its own consistent Jackson.
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
            "--serialization-library",
            "kotlinx_serialization",
            "--validation-library",
            "no_validation",
        )
      }
      doFirst { fabriktOut.get().asFile.mkdirs() }
    }

kotlin.sourceSets.named("main") { kotlin.srcDir(fabriktOut.map { it.dir("src/main/kotlin") }) }

tasks.named("compileKotlin") { dependsOn(fabriktGenerate) }

dependencies {
  fabrikt("com.cjbooms:fabrikt:23.0.0")
  implementation(libs.kotlinx.serialization.json)
}
