# Remli for Android

The Android version of Remli, built natively in Kotlin and Jetpack Compose beside the iOS
app. Nothing in this folder is used by the iOS build, and nothing outside it is used by
this one.

| | |
|---|---|
| Package | `com.chrisallenclark.remli` (same as the iOS bundle ID) |
| Supports | Android 8.0+ (API 26). Android 10–16 is the polished, fully tested range |
| Targets | API 36 (Android 16), as Google Play requires from 31 Aug 2026 |
| Toolchain | AGP 9.4 · Kotlin 2.4.21 · Gradle 9.8.1 · Compose BOM 2026.09.00 · JDK 21 |

## Building

There is no local build in the cloud development environment — it cannot download the
Android SDK. GitHub Actions is the compiler, exactly as it is for iOS:
[`.github/workflows/android.yml`](../.github/workflows/android.yml) runs on every push to
`remli-android` that touches this folder.

Results are readable without the Actions UI:

- `git ls-remote --tags origin 'refs/tags/android-ci-*'` — the tag name is the result,
  `android-ci-pass-<sha>` or `android-ci-fail-<sha>`.
- `git fetch origin android-ci-log` — error lines, log tails, and every screenshot taken.

The debug APK is attached to each run as the `Remli-debug-apk` artifact and can be
installed directly on a phone (see "Installing a test build" below).

On a machine with Android Studio, open this `android/` folder as the project.

## Installing a test build (before Google Play is set up)

1. On GitHub, open **Actions → Android**, pick the latest green run.
2. Under **Artifacts**, download **Remli-debug-apk** and unzip it.
3. Open the `.apk` on the phone and allow your browser or file manager to install apps when
   asked.

Each CI run signs with a fresh debug key, so installing a newer build over an older one may
fail with "app not installed" — uninstall the old one first. This goes away once builds
arrive through Google Play Internal Testing.

## Layout

```
app/src/main/kotlin/com/chrisallenclark/remli/
    capabilities/   what this phone can do, and the fallback for what it cannot
    ui/theme/       design tokens, copied from the iOS asset catalog
app/src/test/       JVM unit tests and screenshot tests (no emulator)
app/src/androidTest/ instrumented tests, run on the emulator matrix
PARITY.md           feature-by-feature status against iOS
TESTING.md          what is tested where, and how the matrix grows
```

## Rules this project keeps

- **No credentials in the app or the repository.** The Claude key is entered by the person
  using the app and stored in the Android Keystore; Play signing keys live in CI secrets.
- **Voice never leaves the phone.** Where private on-device recognition is unavailable, the
  app offers typing — it never falls back to a cloud recogniser.
- **Advanced AI is an enhancement.** Every feature works without Gemini Nano.
- **Nothing is marked verified without evidence.** See PARITY.md.
