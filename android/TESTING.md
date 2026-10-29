# Testing

Layered so the cheap checks run on everything and the expensive ones are added as there is
something for them to catch.

## Today (A1)

| Layer | Where | Runs | Covers |
|---|---|---|---|
| Unit | JVM, CI `build` job | every push | Ported iOS suites (importance, naming, smart collections, search, step visibility, appearance); capability decisions |
| Store | JVM + real SQLite (Robolectric) | every push | What is saved is what comes back after the database is closed and reopened; delete cascades; no-op edits write nothing |
| Screenshot | JVM (Robolectric + Roborazzi), CI `build` job | every push | Every A1 screen at 360, 411 and 480dp, light and dark, and 200% text |
| Lint | CI `build` job | every push | Errors fail the build; findings are printed into the log |
| End-to-end | Emulators, CI `emulator` job | every push | Android 8.0 (small), 10 (standard), 16 (large): capture, cancel, empty save, pin, delete, open, edit and rename, leave mid-edit, importance, status, appearance, activity restart — each checked against the database file afterwards |
| iOS comparison | Emulator screenshots vs `ios-reference` | every push / on change | The same walk on both platforms, light and dark, compared by eye (see PARITY.md) |

Every screenshot is pushed to the `android-ci-log` branch after each run, with the JUnit
results.

**Known gaps in A1, on purpose:**

- The release build (R8 shrinking) is not built in CI yet. It arrives with signing in A10.
- Nothing has run on a real phone.
- Animations are checked for correctness only (the right state at the end), not frame by
  frame.

## How it grows

| When | Added |
|---|---|
| A2 | Android 12 and 13 added to the emulator matrix (on-device speech starts at 12) |
| A4 | Startup and Map frame-time benchmarks on the emulator, with budgets that fail the build |
| A5 | Foldable and tablet emulator profiles |
| A6 | Android 14 (exact-alarm restrictions) added to the matrix |
| A9 | Firebase Test Lab on real Samsung, Pixel, Motorola and OnePlus hardware, before releases |

## What simulation cannot prove

Real microphones and speech recognition, Gemini Nano, and manufacturer battery management
(Samsung, OnePlus, Xiaomi) only behave truthfully on real hardware. Those are verified on
real devices — Test Lab, your phone, and Internal Testing — and PARITY.md says which.
