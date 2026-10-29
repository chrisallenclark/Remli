plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.roborazzi)
}

android {
    namespace = "com.chrisallenclark.remli"

    // compileSdk only decides which APIs the code can *see*. Current AndroidX releases
    // require 37, and raising it changes nothing about which phones can install the app
    // (minSdk) or which platform behaviours it opts into (targetSdk).
    compileSdk = 37

    defaultConfig {
        // Same identifier as the iOS bundle. Permanent once the app exists on Google Play.
        applicationId = "com.chrisallenclark.remli"

        // Android 8.0. Android 10–16 is where the experience is polished and tested on every
        // change; 8 and 9 are supported with graceful fallbacks — see DeviceCapabilities.
        minSdk = 26
        // Google Play requires new apps and updates to target API 36 (Android 16) from
        // 31 August 2026. Moved to 37 deliberately, once its behaviour changes are tested.
        targetSdk = 36

        // CI passes its run number so every build that could reach a phone is newer than
        // the last. Local builds stay at 1.
        versionCode = (project.findProperty("remli.versionCode") as String?)?.toIntOrNull() ?: 1
        // Kept in step with MARKETING_VERSION in ../project.yml.
        versionName = "0.1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // No signingConfig here on purpose. Release signing is wired up in the Play
            // release workflow from repository secrets; no key ever lives in this repo.
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }

    testOptions {
        unitTests {
            // Robolectric needs resources to render screenshot tests.
            isIncludeAndroidResources = true
            all {
                it.systemProperty("robolectric.pixelCopyRenderMode", "hardware")
                // Robolectric's SDK 36 sandbox sets up ApplicationSharedMemory through
                // FileDescriptor internals that JDK 17+ hides. Test JVM only; the app is
                // unaffected.
                it.jvmArgs(
                    "--add-exports=java.base/jdk.internal.access=ALL-UNNAMED",
                    "--add-opens=java.base/java.io=ALL-UNNAMED",
                )
                // Full stack traces in the build log. CI output is the only window into a
                // failure from the cloud session, so a one-line summary is not enough.
                it.testLogging {
                    events("failed")
                    exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
                    showCauses = true
                    showStackTraces = true
                }
            }
        }
    }

    lint {
        // Lint runs in CI on every build. Errors fail it; warnings are reported.
        abortOnError = true
        checkReleaseBuilds = false
        // Findings printed into the build log, which is the only place the cloud session
        // can read them.
        textReport = true
        textOutput = file("stdout")
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.ktx)

    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.foundation)
    implementation(libs.compose.ui.tooling.preview)
    debugImplementation(libs.compose.ui.tooling)
    debugImplementation(libs.compose.ui.test.manifest)

    testImplementation(libs.junit)
    testImplementation(libs.robolectric)
    testImplementation(libs.roborazzi)
    testImplementation(libs.roborazzi.compose)
    testImplementation(libs.roborazzi.junit.rule)
    testImplementation(libs.androidx.test.core)
    testImplementation(platform(libs.compose.bom))
    testImplementation(libs.compose.ui.test.junit4)

    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(platform(libs.compose.bom))
    androidTestImplementation(libs.compose.ui.test.junit4)
}
