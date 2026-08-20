plugins {
  alias(libs.plugins.kotlin.jvm) apply false
  alias(libs.plugins.kotlin.serialization) apply false
  alias(libs.plugins.shadow) apply false
  alias(libs.plugins.versionCatalogUpdate)
  alias(libs.plugins.ktfmt) apply false
  alias(libs.plugins.detekt) apply false
}

val kotlinJvmPluginId = libs.plugins.kotlin.jvm.get().pluginId
val ktfmtPluginId = libs.plugins.ktfmt.get().pluginId
val detektPluginId = libs.plugins.detekt.get().pluginId

// Java 21 is the current broadly adopted LTS
val usedJavaVersion = 21

allprojects {
  repositories {
    // Virtually all modules need Maven Central dependencies
    mavenCentral()
  }
}

subprojects {
  pluginManager.withPlugin(kotlinJvmPluginId) {
    pluginManager.apply(ktfmtPluginId)
    pluginManager.apply(detektPluginId)

    tasks.named("check") {
      dependsOn(tasks.named("ktfmtCheck"))
    }

    extensions.configure<JavaPluginExtension> {
      toolchain {
        // Pinned rather than inheriting whatever JDK is on PATH, so local and CI builds agree.
        languageVersion = JavaLanguageVersion.of(usedJavaVersion)
      }
    }

    tasks.withType<JavaCompile>().configureEach {
      // Preserve parameter names in bytecode for runtime reflection.
      options.compilerArgs.add("-parameters")
    }
  }

  tasks.withType<Test>().configureEach { useJUnitPlatform() }
}
