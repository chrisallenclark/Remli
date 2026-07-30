# Remli

**Capture the idea. Find the thread.**

An iOS app for people whose ideas arrive at bad moments and then die in a notes app.

Speak or type an idea in under a second. Remli titles it, files it into a category it
invented from your own thinking, and — the part a notes app never does — links it to your
other ideas and tells you **why** they connect. Then it brings them back to you: at times
you choose, when your calendar goes quiet, or in a weekly review.

## What makes it different

- **Capture never waits on AI.** The idea is saved the instant you stop talking.
  Enrichment happens afterwards. No network, no model, no problem — nothing is ever lost.
- **Connections are explained, not implied.** Every link between two ideas carries a
  written reason and a type: *builds on*, *prerequisite for*, *variant of*, *contradicts*.
- **Paths, not just a graph.** Because prerequisite links form a directed graph, Remli can
  show you the actual route from where you are to a finished idea.
- **Private by default.** Intelligence runs on-device with Apple's Foundation Models.
  Ideas sync only through your own iCloud. There is no server.

## Status

Feature-complete and building green. Awaiting an Apple Developer account to ship the
first TestFlight build.

| | Phase | State |
|---|---|---|
| P0 | Scaffolding, CI, TestFlight pipeline | ✅ |
| P1 | Design system, data model, text capture | ✅ |
| P2 | Voice capture and live transcription | ✅ |
| P3 | Auto-titling, emergent categories, idea vs task | ✅ |
| P4 | Connection engine, graph and Paths | ✅ |
| P5 | Resurfacing and notifications | ✅ |
| P6 | Widgets, Action Button, Siri | ✅ |
| P7 | Semantic search and smart collections | ✅ |
| P8 | Optional Claude provider | ✅ |
| P9 | App Store readiness | ✅ |

## Requirements

iOS 26 or later. Apple Intelligence (iPhone 15 Pro and newer) for on-device enrichment;
without it the app falls back to keyword tagging, or you can supply a Claude API key.

## Building

There is no `.xcodeproj` in this repo — it is generated from [`project.yml`](project.yml).

```sh
brew install xcodegen
xcodegen generate
open Remli.xcodeproj
```

CI does the same thing on every push. To get a build onto a phone, see [SETUP.md](SETUP.md).

## Layout

```
Sources/Remli/        app code
Resources/            Info.plist, asset catalog
scripts/              parse-check.sh — Linux syntax pre-flight
.github/workflows/    syntax (Linux) · ci (macOS build) · release (TestFlight)
project.yml           the project definition
```
