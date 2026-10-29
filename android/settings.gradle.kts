// Remli for Android.
//
// Lives beside the iOS app in the same repository and shares nothing with its build: the
// iOS project is generated from ../project.yml by XcodeGen, this one is plain Gradle. A
// change on one side can never break the other side's compile.

pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "Remli"
include(":app")
