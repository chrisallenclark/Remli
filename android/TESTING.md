# Testing

Layered so the cheap checks run on everything and the expensive ones are added as there is
something for them to catch.

## Today (A0)

| Layer | Where | Runs | Covers |
|---|---|---|---|
| Unit | JVM, CI `build` job | every push | Capability and fallback decisions for every Android version, memory size and speech setup |
| Screenshot | JVM (Robolectric + Roborazzi), CI `build` job | every push | 360dp small, 411dp standard, 480dp large; light and dark; 200% text |
| Lint | CI `build` job | every push | Android lint; errors fail the build |
| Emulator | GitHub Actions, KVM | every push | Launch and draw on Android 8.0 (small screen), 10 (standard), 16 (large) |

Screenshots from both the JVM tests and the emulators are pushed to the `android-ci-log`
branch after every run, along with the JUnit XML results.

**Known gaps in A0, on purpose:**

- Screenshots are *recorded*, not *compared*. Nothing fails if a screen changes. Baselines
  are committed in A1, when there are real screens worth protecting.
- The release build (R8 shrinking) is not built in CI yet. It arrives with signing in A10.
- Emulator AVDs on Android 8 and 10 have under 3 GB of RAM, so they report the reduced-
  effects mode. That is the low-memory path working as designed, and is how the reduced path
  gets exercised on every push.
- Nothing has run on a real phone.

## How it grows

| When | Added |
|---|---|
| A1 | Screenshot baselines committed; CI fails on unintended visual change. Unit tests ported from `../Tests/*.swift` with identical cases |
| A2 | Android 12 and 13 added to the emulator matrix (on-device speech starts at 12) |
| A4 | Startup and Map frame-time benchmarks on the emulator, with budgets that fail the build |
| A5 | Foldable and tablet emulator profiles |
| A6 | Android 14 (exact-alarm restrictions) added to the matrix |
| A9 | Firebase Test Lab on real Samsung, Pixel, Motorola and OnePlus hardware, before releases |

## What simulation cannot prove

Real microphones and speech recognition, Gemini Nano, and manufacturer battery management
(Samsung, OnePlus, Xiaomi) only behave truthfully on real hardware. Those are verified on
real devices — Test Lab, your phone, and Internal Testing — and PARITY.md says which.
