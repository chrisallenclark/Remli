This repo is Remli, an iOS idea-capture and organization app with voice and text capture. It is NOT Macrova, Mealixr, Closr, Keepr, Aulorvy.com, or Hybrid Performance.

Read `docs/AULORVY_PROFILE.md` first for owner context and never-do rules.

This file describes the tree on the default branch `main` (tip `8122c80`, 2026-08-05) unless a line says otherwise. GitHub: `chrisallenclark/Remli` (public). There is no `HANDOFF.md`, `AGENTS.md`, or `.cursor/rules` in this tree.

## Purpose and audience

Remli captures a thought by voice or text, then titles it, files it, links it to other ideas with a written reason, and brings it back later. The README tagline is "Capture the idea. Find the thread."

The README's audience is people whose ideas arrive at bad moments and then die in a notes app. The app is iPhone-only (`TARGETED_DEVICE_FAMILY` is `"1"` in `project.yml`), portrait-only (`Resources/Info.plist`), and requires iOS 26 or later. On-device enrichment needs Apple Intelligence (README: iPhone 15 Pro and newer); without it the app falls back to keyword tagging, or the user can supply a Claude API key.

There is no Remli account and no Remli server. Ideas stay on the phone and, when iCloud is set up, sync through the user's own private CloudKit database (`iCloud.com.chrisallenclark.remli`).

The four tabs in `Sources/Remli/RootView.swift` are Ideas, Map, Paths, and Review. Capture is a sheet, not a tab. Widgets, a Control Center control, Siri ("Capture an idea"), and the URL scheme `remli://` open capture directly (`Sources/Shared/Intents/CaptureRoute.swift`).

TBD (Chris to confirm): Is the audience only Chris, or a public App Store product with a price? README and `SETUP.md` describe shipping, and they do not name a customer segment or a price.

## Brand and UI rules

Home-screen name is **Remli** (`CFBundleDisplayName` in `Resources/Info.plist`). `SETUP.md` says the App Store Connect listing name is `Remli: Think. Connect. Build.` because plain "Remli" was reserved. Support and privacy copy live in `docs/index.md` and `docs/privacy.md`. Support contact written there: chrisallenclarkjr@gmail.com.

Public tagline, in `README.md` and `docs/_config.yml`: "Capture the idea. Find the thread."

Voice in the README, permission strings, and privacy policy: direct, second person, and specific about what the app does not do (no saved audio, no reading event titles, no server). `Theme.Motion` comments say motion should settle quickly, with no bounce that would read as toy-like.

All visual tokens go through `Sources/Shared/Design/Theme.swift`. Colors are asset-catalog names so views do not branch on `colorScheme`. The app tint is `Theme.Palette.ember` (`Sources/Remli/RemliApp.swift`). Launch screen color is `Canvas`.

Colors in `Resources/Assets.xcassets` (sRGB). `AccentColor` matches `Ember`.

| Token | Light | Dark |
|---|---|---|
| Canvas | `#FAF9F7` | `#0B0B0D` |
| Surface | `#FFFFFF` | `#16161A` |
| Ink | `#16161A` | `#F2F0EC` |
| InkMuted | `#63605A` | `#9A958C` |
| Hairline | `#E4E1DB` | `#26262B` |
| Ember / Accent | `#B4561A` | `#E8A33D` |

Type, from `Theme.Typography`: idea text uses the system serif (the comment names New York); structural UI stays in the system sans (the comment names SF Pro). Roles: `display`, `title`, `ideaBody`, `sectionLabel`, `meta`, `control`.

Spacing is a 4pt scale: 4, 8, 12, 16, 24, 32, 48 (`Theme.Space`). Radii: 8, 14, 22, and pill `999` (`Theme.Radius`). Grouped content uses the `cardBackground()` modifier (surface fill, 14pt continuous corners, 0.5pt hairline). Tabs and rows use SF Symbols.

These tokens are from `main`. Commits on the unmerged branch `claude/idea-capture-ios-app-1k01vx` (see Current status) include subjects that change the palette and add Spaces. Do not treat this table as the design on that branch.

TBD (Chris to confirm): Which palette is current, the tokens on `main` or the later palette commits on `claude/idea-capture-ios-app-1k01vx`?

## Stack

- Language: Swift. `project.yml` sets `SWIFT_VERSION` to `"5.0"`. The comment there says Swift 6 strict concurrency is deferred until a local compiler can take it.
- UI and data: SwiftUI and SwiftData. No CocoaPods. No `Package.swift` and no committed SPM dependencies. `Sources/Shared` is a source folder compiled into the app target, not a package.
- iOS deployment target: `26.0` (`project.yml`). Marketing version `0.1.0`. `CURRENT_PROJECT_VERSION` in the project is `"1"`; the release workflow overrides it with `github.run_number`.
- Xcode and XcodeGen are not pinned. CI runs `brew install xcodegen` and selects the newest Xcode under `/Applications` on `macos-latest`.
- Syntax workflow parses with the `swift:6.1` container. That container is the Linux parse check only. It is not the app's Swift language mode.
- Apple frameworks imported in this tree: SwiftUI, SwiftData, FoundationModels, Speech, AVFoundation, NaturalLanguage, EventKit, UserNotifications, BackgroundTasks, WidgetKit, AppIntents, Security (Keychain), Observation, CoreGraphics.
- Data stores: SwiftData `ModelContainer` (`Idea`, `IdeaCategory`, `IdeaLink` in `Sources/Shared/Models/RemliSchema.swift`); CloudKit private database `iCloud.com.chrisallenclark.remli`; `UserDefaults` for the Claude on/off flag, Claude model, and resurfacing settings; iOS Keychain for the optional Anthropic API key (`KeychainStore.swift`). If the persistent store fails to open, the app falls back to an in-memory container.
- External services: none owned by Remli. Optional Anthropic Messages API at `https://api.anthropic.com/v1/messages`, version header `2023-06-01`, called with `URLSession` (no Anthropic SDK) from `ClaudeIntelligence.swift`. Model ids in code: `claude-opus-5` (default), `claude-sonnet-5`, `claude-haiku-4-5`. Beta header `server-side-fallback-2026-07-01`. Claude is off until the user passes `ClaudeConsentView`. Provider order in `IntelligenceFactory.swift`: Claude if active, then `FoundationModelsIntelligence`, then `HeuristicIntelligence`.
- Bundle ids: `com.chrisallenclark.remli` and widget `com.chrisallenclark.remli.widgets`. Background task id `com.chrisallenclark.remli.refresh` (must match `ResurfacingCoordinator`).
- The repo was renamed from `Cued` to `Remli` (`SETUP.md`). GitHub redirects the old name.

## Build, run, and test commands

There is no `.xcodeproj` in the repo. `.gitignore` ignores it. `project.yml` is the project definition. README commands, on a Mac:

```sh
brew install xcodegen
xcodegen generate
open Remli.xcodeproj
```

CI generates the project with `xcodegen generate --spec project.yml`.

Linux syntax pre-flight (this is what `.github/workflows/syntax.yml` runs; it needs `swiftc`):

```sh
chmod +x scripts/parse-check.sh
./scripts/parse-check.sh
```

`scripts/parse-check.sh` runs `swiftc -parse` on every `.swift` file under `Sources`, and under `Tests` or `Packages` if those directories exist. On `main` only `Sources` exists. The script does not typecheck. Apple frameworks are not on Linux.

What CI actually runs, from the workflow files:

| Workflow | File | When | What |
|---|---|---|---|
| Syntax | `.github/workflows/syntax.yml` | push to any branch, pull request, `workflow_dispatch` | `swift:6.1` parse via `scripts/parse-check.sh`, plus a Python check that `project.yml`, `.github/**/*.yml`, and `*.plist` parse |
| CI | `.github/workflows/ci.yml` | same triggers | `xcodebuild build` of scheme `Remli`, Debug, destination `generic/platform=iOS Simulator`, `CODE_SIGNING_ALLOWED=NO` |
| Release to TestFlight | `.github/workflows/release.yml` | `workflow_dispatch` only, optional `notes` input (default "Automated build") | archive, export IPA, upload to TestFlight |

On `main` there is no test target in `project.yml`, no `Tests/` directory, and no `xcodebuild test` step. A green CI build means the app compiled for the simulator. It does not mean unit tests ran.

The owner has no Mac (`docs/AULORVY_PROFILE.md`). Day-to-day compile feedback is the GitHub Actions log, plus the `ci-pass-<sha>` / `ci-fail-<sha>` tag and, on failure, the orphan branches `ci-log` and `release-log`. Those workflows keep a single `ci-*` tag and a single `rel-*` tag; they delete the previous one.

Last recorded checks on `main` tip `8122c80` (2026-08-05): "Parse Swift sources" success, "Validate project.yml" success, "Build (iOS Simulator)" success.

## Deploy target and release process

Target for a phone build is TestFlight, not a Remli server. `SETUP.md` is the manual path: Apple Developer Program ($99/year, Individual), public repo (this repo is public), App Store Connect API key with the **App Manager** role, four GitHub Actions secrets (`TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`), an App Store Connect app record, and the iCloud container `iCloud.com.chrisallenclark.remli`. Signing uses `xcodebuild -allowProvisioningUpdates` and that API key. The workflow does not use fastlane match. `fastlane/` is only mentioned in `.gitignore`.

On this branch, a person starts **Release to TestFlight** with `workflow_dispatch`. The workflow checks the four secrets, archives Release for `generic/platform=iOS`, sets `CURRENT_PROJECT_VERSION` to the Actions run number, exports an App Store Connect IPA, and uploads with `apple-actions/upload-testflight-build@v4`. `ITSAppUsesNonExemptEncryption` is false. The IPA artifact is kept 14 days. `SETUP.md` says the first build takes 10–15 minutes, plus 5–15 minutes of Apple processing, then it shows up in TestFlight.

CI on push does not ship a build. It only compiles.

GitHub Pages is the intended host for the support page and privacy policy (`docs/`, Jekyll theme `jekyll-theme-minimal` in `docs/_config.yml`). `SETUP.md` step 7 is a manual setting: deploy from branch `main`, folder `/docs`. There is no Pages workflow. The GitHub Pages API for this repo returned 404 on 2026-11-25, so the site is not published. `SETUP.md` says those URLs are required before a public App Store listing.

No workflow in this tree submits the app for public App Store review.

The release workflow file on the unmerged branch `claude/idea-capture-ios-app-1k01vx` is not this file. Successful "Release to TestFlight" runs on that branch were triggered by `push` (latest success 2026-08-18, run `32177986977`, commit "Let the name of an idea be yours"). Do not assume `main`'s `workflow_dispatch`-only trigger is what that branch does.

## Current status

**On `main`, as of commit `8122c80` (2026-08-05), "Remli: voice-first idea capture with explained connections and resurfacing (#1)".** The README phase table marks P0–P9 done: scaffolding and CI, design system and text capture, voice capture, enrichment, connection engine and Paths, resurfacing, widgets / Action Button / Siri, search and smart collections, optional Claude, and App Store readiness files (privacy manifest, export compliance, iCloud entitlement, `docs/`). Those features have source files on `main`. This agent has not installed or run the app.

Phase commits on 2026-07-30: `66b0a4a` P0, `f80d3c1` P1, `bd09850` P2, `fae60ee` P3, `be1aa8a` P4a, `e725a2e` P4b, `5f49be5` P5, `4cdd9e8` P6, `eaf016d` P7, `bc6af8e` P8, `0cbce55` P9. Docs and CI follow-ups landed 2026-08-05, including the squash/merge that is `main`'s tip.

README on `main` still says "Awaiting an Apple Developer account to ship the first TestFlight build." That sentence is older than the release history below.

**Not on `main`:**

- `origin/claude/idea-capture-ios-app-1k01vx` is 50 commits ahead of `main` and contains every commit on `main`. Tip `c3d5dc3`, 2026-08-18, "Let the name of an idea be yours". Subjects after `main` include a workshop, Spaces, roadmaps, folders, palette changes, the first tests, and CI changes. Git tags `ci-pass-c3d5dc34e1ad76c00c60d8050eb5d89256efbf02` and `rel-pass-c3d5dc34e1ad76c00c60d8050eb5d89256efbf02` point at that tip. The workflows write those tags when the matching job succeeds, then delete the previous `ci-*` or `rel-*` tag. So the tags do not describe `main`'s tip.
- GitHub Actions "Release to TestFlight" on that branch completed successfully several times between 2026-08-11 and 2026-08-18. A successful run means the upload job finished. It does not, by itself, prove a tester can still install the build.
- `origin/remli-android` is 68 commits not in `main`. Tip `78b9f1b`, 2026-10-29, "Commit approved screenshot baselines; CI now verifies against them". Tag `android-ci-pass-78b9f1b576520bbacecf01d1607f1cf93f5ace29` points there.
- `origin/ios-reference` tip `fa9c2a7`, 2026-10-29, "iOS reference screens for e8cb6e2db8e104f22b9e23cc50b321dd558bc150".

**Known gaps in the `main` tree:**

- No unit or UI test target.
- CloudKit remote notifications are deliberately omitted. `Resources/Remli.entitlements` says sync is on launch and foreground, and that push can wait until the pipeline is proven.
- `project.yml` still has a P0 comment that capabilities arrive later. The entitlement file and `Info.plist` on `main` already include CloudKit and background modes. Trust the plist and entitlements over that comment.
- Swift 6 language mode is not enabled.
- Xcode is unpinned.
- Privacy and support pages are written and not published (Pages API 404 on 2026-11-25).
- `main`'s README "awaiting an Apple Developer account" line disagrees with later successful TestFlight workflow runs on the other branch.

TBD (Chris to confirm): Should agents treat `main` or `claude/idea-capture-ios-app-1k01vx` as the current product?
TBD (Chris to confirm): Is `remli-android` in scope for agents in this repo?
TBD (Chris to confirm): Can testers still install the TestFlight build from the 2026-08-18 release run, and is the Apple Developer Program membership still active?
TBD (Chris to confirm): Are GitHub secrets `TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_KEY_P8` still present and valid? They are not in the repo. A release job succeeded on 2026-08-18, which required them then.
TBD (Chris to confirm): When should GitHub Pages be turned on for `docs/`?
TBD (Chris to confirm): Is a public App Store release planned? No workflow in this tree submits for review.
TBD (Chris to confirm): Should CI pin an Xcode version? Workflows use the newest Xcode on `macos-latest`, and the repo does not record which version built `8122c80`.

## Repo-specific rules

- Work on a branch and open a PR. Do not push to `main`, merge, or deploy unless Chris says so.
- Do not add or change secrets, API keys, hosting env vars, or new integrations without Chris's OK. Never commit secret files (`.env`, `AuthKey_*.p8`, `*.p12`, `*.mobileprovision`, `FirebaseOptions.plist`). `.gitignore` already ignores `.env`, `AuthKey_*.p8`, `*.p12`, and `*.mobileprovision`.
- Keep Remli separate from Macrova, Mealixr, Closr, Keepr, Aulorvy.com, and Hybrid Performance. Do not share data, customers, branding, or accounts across them.
- Separate verified facts from assumptions. If it is not in the repo or in a command output you just ran, mark it TBD. Do not invent versions, status, or names.
- Do not commit `*.xcodeproj` or `*.xcworkspace`. Change `project.yml` and let XcodeGen regenerate.
- Do not put `DEVELOPMENT_TEAM` in `project.yml`. Release passes it on the `xcodebuild` command line so ordinary CI needs no Apple account.
- SwiftData models that sync: every stored property has a default, relationships stay optional, and there are no `@Attribute(.unique)` constraints (`Sources/Shared/Models/Idea.swift`). CloudKit does not support unique constraints.
- The widget target compiles `Sources/Widgets` plus `Sources/Shared/Intents/CaptureRoute.swift` only. Do not pull the rest of `Sources/Shared` into the extension.
- `BGTaskSchedulerPermittedIdentifiers` in `Resources/Info.plist` must match `ResurfacingCoordinator.refreshTaskIdentifier`.
- Saving a capture must not wait on a model. Enrichment runs after the idea is stored (README and `EnrichmentService`).
- Claude stays off unless the user consents. The API key stays in the Keychain. Disabling the feature deletes the key.
- Do not add `aps-environment` or remote-notification background mode unless Chris asks. The entitlements comment explains why it was left out.
- `scripts/parse-check.sh` is a parse check, not a typecheck. A clean parse does not mean the macOS build will pass.

## Key paths map

| Path | What it does |
|---|---|
| `project.yml` | XcodeGen spec: targets `Remli` and `RemliWidgets`, bundle ids, iOS 26, Swift 5 language mode, version `0.1.0` |
| `Sources/Remli/RemliApp.swift` | App entry, SwiftData container, background-task registration, ember tint |
| `Sources/Remli/RootView.swift` | Four tabs, capture sheet, settings sheet, `remli://` routing |
| `Sources/Remli/Views/` | Capture, idea list and detail, map, paths, review, settings, Claude consent |
| `Sources/Shared/Design/Theme.swift` | Colors, type, spacing, radii, motion, `cardBackground()` |
| `Sources/Shared/Models/` | `Idea`, `IdeaCategory`, `IdeaLink`, enums, `RemliSchema` (CloudKit container) |
| `Sources/Shared/Services/Intelligence/` | Enrichment chain: Claude, Foundation Models, heuristic fallback, Keychain |
| `Sources/Shared/Services/Connections/` | Links, similarity, embeddings, graph layout, paths |
| `Sources/Shared/Services/Speech/` | On-device voice capture and transcription |
| `Sources/Shared/Services/Resurfacing/` | Scoring, notifications, calendar gaps, background refresh |
| `Sources/Shared/Services/Search/` | Semantic plus literal search, smart collections |
| `Sources/Widgets/` | Home-screen capture widget and Control Center control |
| `Resources/` | `Info.plist`, `Widgets-Info.plist`, `Remli.entitlements`, asset catalog, `PrivacyInfo.xcprivacy` |
| `.github/workflows/` | `syntax.yml` (Linux parse), `ci.yml` (simulator build), `release.yml` (manual TestFlight) |
| `scripts/parse-check.sh` | `swiftc -parse` pre-flight used by the Syntax workflow |
| `README.md`, `SETUP.md` | Product summary and the manual Apple / TestFlight setup |
| `docs/` | Jekyll support page (`index.md`), privacy policy (`privacy.md`), owner profile (`AULORVY_PROFILE.md`) |
