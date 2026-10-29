// Plugins are declared here once, with versions, and applied per module.
//
// AGP 9 compiles Kotlin itself ("built-in Kotlin"), so there is no kotlin-android plugin.
// The Kotlin Gradle plugin is still put on the classpath explicitly so the Compose
// compiler plugin and the Kotlin compiler are guaranteed to be the same version — a
// mismatch between the two is a build failure, not a warning.
buildscript {
    dependencies {
        classpath(libs.kotlin.gradle.plugin)
    }
}

plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.roborazzi) apply false
}
