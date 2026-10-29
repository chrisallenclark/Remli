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

## Features

| Feature | iOS source | Android | Status | Evidence |
|---|---|---|---|---|
| Device capability check & fallbacks | — (Android only) | `capabilities/` | Built | `DeviceCapabilitiesTest` |
| Colour tokens (light/dark) | `Resources/Assets.xcassets`, `Theme.swift` | `ui/theme/Palette.kt` | Built | values copied; screenshot review pending |
| Typography (serif idea text) | `Theme.swift` | — | — | A1: open-licence stand-ins for New York / SF Pro |
| Spacing, radii, motion tokens | `Theme.swift` | — | — | A1 |
| Data model (Idea, Space/Collection, Link) | `Sources/Shared/Models` | — | — | A1 |
| Ideas list, pinned, empty state | `IdeasListView.swift` | — | — | A1 |
| Text capture with optional name | `CaptureSheet.swift` | — | — | A1 |
| Idea detail, tags, importance | `IdeaDetailView.swift`, `ImportanceControl.swift` | — | — | A1 |
| Voice capture, live transcript | `VoiceCaptureController.swift` | — | — | A2 — on-device only, typing fallback |
| Enrichment: heuristic floor | `HeuristicIntelligence.swift` | — | — | A3 |
| Enrichment: Claude (opt-in, own key) | `ClaudeIntelligence.swift`, `ClaudeConsentView.swift` | — | — | A3 |
| Enrichment: on-device model | `FoundationModelsIntelligence.swift` | — | — | A3 — Gemini Nano where present, else heuristic |
| Emergent Spaces & Collections | `IdeaCategory.swift`, `EnrichmentService.swift` | — | — | A3 |
| Embeddings & similarity | `EmbeddingService.swift`, `Similarity.swift` | — | — | A3 |
| Connections, review of proposals | `ConnectionEngine.swift`, `ConnectionsSection.swift` | — | — | A4 |
| Map (force layout, focus mode) | `MapView.swift`, `GraphLayout.swift`, `MapFocusLayout.swift` | — | — | A4 |
| Roadmaps & roadmap detail | `RoadmapsView.swift`, `RoadmapDetailView.swift`, `RoadmapPreview.swift` | — | — | A4 |
| Workshop | `WorkshopView.swift` | — | — | A4 |
| Spaces deck & Space view | `SpacesView.swift`, `SpaceView.swift` | — | — | A5 |
| Space covers, palette, icons | `SpaceCover.swift`, `SpaceCoverPreset.swift`, `SpacePalette.swift`, `SpaceSymbol.swift` | — | — | A5 — SF Symbols mapped to Material Symbols |
| Resurfacing notifications | `Resurfacing/*` | — | — | A6 |
| Calendar free time | `FreeTimeFinder.swift` | — | — | A6 |
| Review | `ReviewView.swift` | — | — | A6 |
| Search & smart collections | `IdeaSearch.swift`, `SmartCollection.swift` | — | — | A7 |
| Settings & appearance | `SettingsView.swift`, `Appearance.swift` | — | — | A1 (appearance) → A6 |
| Fast capture routes | `Widgets/*`, `RemliShortcuts.swift`, `FastCaptureGuide.swift` | — | — | A8 — Differs: widget, Quick Settings tile, shortcuts, share target |
| iCloud sync | `RemliSchema.swift` | — | Differs | No iCloud on Android; local storage + Android backup. Cross-platform sync is an open decision |
