# Parity with iOS

**Last iOS commit ported:** `c3d5dc3` ("Let the name of an idea be yours") on
`claude/idea-capture-ios-app-1k01vx`.

To see what iOS has changed since:

```sh
git fetch origin claude/idea-capture-ios-app-1k01vx
git log --oneline c3d5dc3..origin/claude/idea-capture-ios-app-1k01vx -- Sources Resources Tests
```

Port those changes, then move the commit above forward.

## Status key

- **—** not started
- **Built** — implemented, compiles, covered by automated tests where noted
- **Emulator** — additionally exercised on the CI emulator matrix
- **Device** — additionally checked on a real phone, named
- **Differs** — intentionally different on Android, with the reason

A feature is never moved past **Built** without the evidence that status names.

## How visual parity is checked

`.github/workflows/ios-reference.yml` builds the iOS app from the unchanged iOS sources on a
Mac runner and screenshots each A1 screen in light and dark, by driving the simulator
through the same walk as `app/src/androidTest/.../ReferenceScreensTest.kt` does on Android.
The images are published to the `ios-reference` branch (iOS) and `android-ci-log`
(Android, named `api<level>_<appearance>_<step>`), so each pair can be compared side by
side. Comparison is by eye: the two platforms render text differently enough that a pixel
diff between them means nothing. Pixel diffs are used Android-against-Android instead —
see TESTING.md.

Under test the iOS app shows a red "Storage unavailable" banner (it runs on an in-memory
store), and its enrichment — titles, Spaces, tags — runs; neither applies to the Android
screenshots. Ignore both when comparing.

## Features

| Feature | iOS source | Android | Status | Evidence |
|---|---|---|---|---|
| Device capability check & fallbacks | — (Android only) | `capabilities/` | Emulator | `DeviceCapabilitiesTest`; shown in Settings → This phone |
| Colour tokens (light/dark) | `Resources/Assets.xcassets`, `Theme.swift` | `design/Theme.kt` | Emulator | Values copied; compared against iOS reference screens, light and dark |
| Typography | `Theme.swift` | `design/Theme.kt`, `res/font` | Emulator | Differs: Source Serif 4 for New York, Inter for SF Pro (Apple's fonts may not ship on Android). Same sizes and line heights. Compared against iOS screens |
| Spacing, radii, continuous corners | `Theme.swift` | `design/Theme.kt`, `design/ContinuousShape.kt` | Emulator | Same values; iOS continuous-corner curve reproduced |
| Motion (springs) | `Theme.Motion` | `Theme.Motion` | Built | Same physical springs (stiffness from response). Not compared frame by frame |
| Icons | SF Symbols | `design/Symbol.kt` | Emulator | Differs: Material Symbols Rounded, mapped by SF name (SF Symbols may not ship on Android) |
| Data model (Idea, Space/Collection, Link) | `Sources/Shared/Models` | `model/`, `data/RemliDatabase.kt` | Emulator | Every stored field, same names and raw values. `IdeaStoreTest` (real SQLite, reopened); flow tests read the database file directly |
| Ideas list, pinned-first, empty state | `IdeasListView.swift`, `IdeaRowView.swift` | `ui/IdeasListScreen.kt`, `ui/IdeaRow.kt` | Emulator | `IdeaFlowTest` on Android 8.0, 10, 16; compared with iOS 01, 04, 06 |
| Smart-collection chips | `SmartCollection.swift` | `search/SmartCollection.kt` | Built | `SmartCollectionTest` (port). Chips appear only once enrichment files ideas (A3), so not yet seen on a device |
| Long-press menu (pin, delete) | `IdeasListView.swift` `.contextMenu` | `design/Controls.kt` `ContextMenuOverlay` | Emulator | `IdeaFlowTest.pinningFloatsAnIdeaToTheTop`, `deleteFromTheListRemovesTheIdea`; compared with iOS 05 |
| Search (literal) | `IdeaSearch.swift` | `search/IdeaSearch.kt` | Built | `IdeaSearchTest` (port, all 10 cases). Search by meaning needs embeddings (A3). Not yet exercised on a device |
| Text capture with optional name | `CaptureSheet.swift` | `ui/CaptureSheet.kt` | Emulator | `IdeaFlowTest` capture, cancel, empty-save cases; compared with iOS 02, 03 |
| Voice capture | `VoiceCaptureController.swift` | — | — | A2. On-device only, with typing as the fallback |
| Idea detail: read, tap-to-edit name and body | `IdeaDetailView.swift` | `ui/IdeaDetailScreen.kt` | Emulator | `IdeaFlowTest.anIdeaOpensEditsAndKeepsTheEdits`, `leavingWhileEditingStillSaves`; compared with iOS 07, 11 |
| Importance control | `ImportanceControl.swift` | `ui/ImportanceControl.kt` | Emulator | `ImportanceTest` (port); `IdeaFlowTest.importanceAndStatusArePersisted`; compared with iOS 08 |
| Status | `IdeaDetailView.swift` | `design/Controls.kt` `SegmentedControl` | Emulator | `IdeaFlowTest.importanceAndStatusArePersisted` |
| Detail menu: edit, pin, pursue, delete | `IdeaDetailView.swift` | `ui/IdeaDetailScreen.kt` | Emulator | `IdeaFlowTest`; compared with iOS 10. "Move to a Space…" arrives with Spaces (A5) |
| Settings: appearance | `SettingsView.swift`, `Appearance.swift` | `ui/SettingsSheet.kt`, `design/Appearance.kt` | Emulator | `AppearanceTest` (port); `IdeaFlowTest.appearanceChoiceAppliesAndPersists`. No iOS reference screenshot (see above). Android 8–9 offer Light and Dark only |
| Tab bar, Capture button, sheets | `RootView.swift` | `ui/RemliApp.kt`, `ui/TabBar.kt`, `design/Sheet.kt` | Emulator | Compared with iOS 01–04. Spaces, Map and Roadmaps tabs show a "coming" screen |
| Frosted glass (blur) | system materials | `design/Chrome.kt` | Differs | Translucent fill without blur in A1, on every Android version. Real blur on Android 12+ is still to do |
| Review toolbar button | `RootView.swift` | — | — | Arrives with Review (A6) |
| Enrichment: heuristic floor | `HeuristicIntelligence.swift` | — | — | A3 |
| Enrichment: Claude (opt-in, own key) | `ClaudeIntelligence.swift`, `ClaudeConsentView.swift` | — | — | A3 |
| Enrichment: on-device model | `FoundationModelsIntelligence.swift` | — | — | A3 — Gemini Nano where present, else heuristic |
| Emergent Spaces & Collections | `IdeaCategory.swift`, `EnrichmentService.swift` | — | — | A3 (schema already stored) |
| Embeddings & similarity | `EmbeddingService.swift`, `Similarity.swift` | — | — | A3 (`IdeaSearch.cosine` already ported) |
| Connections, review of proposals | `ConnectionEngine.swift`, `ConnectionsSection.swift` | — | — | A4 |
| Map (force layout, focus mode) | `MapView.swift`, `GraphLayout.swift`, `MapFocusLayout.swift` | — | — | A4 |
| Roadmaps & roadmap detail | `RoadmapsView.swift`, `RoadmapDetailView.swift`, `RoadmapPreview.swift` | — | — | A4 |
| Workshop ("Work on this") | `WorkshopView.swift` | — | — | A4 |
| Spaces deck & Space view | `SpacesView.swift`, `SpaceView.swift` | — | — | A5 |
| Space covers, palette, icons | `SpaceCover.swift`, `SpaceCoverPreset.swift`, `SpacePalette.swift`, `SpaceSymbol.swift` | — | — | A5 |
| Resurfacing, calendar, Review | `Resurfacing/*`, `ReviewView.swift` | — | — | A6 |
| Fast capture routes | `Widgets/*`, `RemliShortcuts.swift`, `FastCaptureGuide.swift` | — | — | A8 — Differs: widget, Quick Settings tile, shortcuts, share target |
| iCloud sync | `RemliSchema.swift` | — | Differs | No iCloud on Android; local storage plus Android backup. Cross-platform sync is an open decision |

## iOS tests ported

| iOS suite | Android | Cases |
|---|---|---|
| `ImportanceTests.swift` — Importance, Idea naming | `model/ImportanceTest.kt` | 12 of 13 (resurfacing case → A6). "Map node weighting" suite → A4 |
| `AppearanceTests.swift` | `design/AppearanceTest.kt` | all, plus the Android 8–9 option set |
| `SmartCollectionTests.swift` | `search/SmartCollectionTest.kt` | all 7 |
| `IdeaSearchTests.swift` | `search/IdeaSearchTest.kt` | all 10 |
| `StepVisibilityTests.swift` | `model/StepVisibilityTest.kt` | 2 of 6 (Space counts, roadmaps → A4/A5), plus rejected links |
| `CaptureLaunchRequestTests`, `GraphLayoutTests`, `MapFocusLayoutTests`, `RoadmapOrderingTests`, `SpaceHierarchyTests`, `SpacePaletteTests`, `SpaceSymbolTests` | — | With their features |
