import SwiftData
import SwiftUI

/// Capture — by voice or by typing.
///
/// The design rule is that nothing stands between having a thought and it being saved.
/// There is no title field, no category picker and no tag entry: all of that is the app's
/// job afterwards, not the user's beforehand.
///
/// Voice and text are not separate modes so much as two ways of filling the same buffer.
/// Dictate, stop, fix a word, dictate some more — it all lands in one place.
struct CaptureSheet: View {

    /// Set by the widget, Action Button and Siri paths, which open straight into recording.
    var autoStartVoice: Bool = false

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var voice = VoiceCaptureController()
    @FocusState private var isFocused: Bool

    /// What the user sees: everything typed so far, plus whatever is being said right now.
    private var displayText: String {
        guard voice.isRunning else { return text }
        let live = voice.transcript
        if live.isEmpty { return text }
        return text.isEmpty ? live : text + " " + live
    }

    private var trimmed: String {
        displayText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool { !trimmed.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.canvas.ignoresSafeArea()

                VStack(spacing: 0) {
                    editor
                    Spacer(minLength: Theme.Space.md)
                    if case .failed(let message) = voice.state {
                        FailureNote(message: message)
                    }
                    micControl
                }
            }
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Task {
                            await voice.cancel()
                            dismiss()
                        }
                    }
                    .foregroundStyle(Theme.Palette.inkMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(voice.isRunning)
        .task {
            // A capture is almost always followed by an enrichment, so warming the model
            // now takes the cold start off the critical path.
            FoundationModelsIntelligence.prewarm()

            if autoStartVoice {
                await voice.start()
            } else {
                isFocused = true
            }
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private var editor: some View {
        if voice.isRunning {
            // Read-only while dictating. Editing text that the transcriber is still
            // rewriting underneath you is a fight nobody wins.
            ScrollView {
                Text(liveAttributed)
                    .font(Theme.Typography.ideaBody)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.top, Theme.Space.md)
            }
            .defaultScrollAnchor(.bottom)
        } else {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("What's the idea?")
                        .font(Theme.Typography.ideaBody)
                        .foregroundStyle(Theme.Palette.inkMuted)
                        .padding(.horizontal, Theme.Space.lg + 5)
                        .padding(.top, Theme.Space.md + 8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $text)
                    .font(Theme.Typography.ideaBody)
                    .foregroundStyle(Theme.Palette.ink)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .focused($isFocused)
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.top, Theme.Space.md)
            }
        }
    }

    /// Committed words in full contrast, the analyzer's current guess dimmed, so it is
    /// visible that the tail may still change.
    private var liveAttributed: AttributedString {
        var result = AttributedString(text.isEmpty ? "" : text + " ")
        result.foregroundColor = Theme.Palette.ink

        var settled = AttributedString(voice.finalizedText)
        settled.foregroundColor = Theme.Palette.ink
        result.append(settled)

        var pending = AttributedString(voice.volatileText)
        pending.foregroundColor = Theme.Palette.inkMuted
        result.append(pending)

        return result
    }

    private var micControl: some View {
        VStack(spacing: Theme.Space.xs) {
            Button {
                Task {
                    if voice.isRunning {
                        await stopDictation()
                    } else {
                        await voice.start()
                    }
                }
            } label: {
                ZStack {
                    if voice.state == .recording {
                        Circle()
                            .fill(Theme.Palette.ember.opacity(0.18))
                            .frame(width: 76 + CGFloat(voice.inputLevel) * 34,
                                   height: 76 + CGFloat(voice.inputLevel) * 34)
                    }

                    Circle()
                        .fill(voice.isRunning ? Theme.Palette.ember : Theme.Palette.surface)
                        .frame(width: 76, height: 76)
                        .overlay(Circle().strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))

                    Image(systemName: iconName)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(voice.isRunning ? Theme.Palette.canvas : Theme.Palette.ember)
                }
            }
            .buttonStyle(.plain)
            .disabled(voice.state == .finishing)
            .animation(Theme.Motion.standard, value: voice.inputLevel)
            .animation(Theme.Motion.standard, value: voice.isRunning)

            Text(hint)
                .font(Theme.Typography.meta)
                .foregroundStyle(Theme.Palette.inkMuted)
                .contentTransition(.opacity)
        }
        .padding(.bottom, Theme.Space.lg)
    }

    private var iconName: String {
        switch voice.state {
        case .recording: return "stop.fill"
        case .preparing, .finishing: return "ellipsis"
        default: return "mic.fill"
        }
    }

    private var hint: String {
        switch voice.state {
        case .preparing: return "Getting ready…"
        case .recording: return "Listening — tap to stop"
        case .finishing: return "Finishing up…"
        default: return "Tap to speak"
        }
    }

    // MARK: - Actions

    private func stopDictation() async {
        await voice.stop()
        // Fold the transcript into the editable buffer so it can be corrected by hand.
        let spoken = voice.transcript
        if !spoken.isEmpty {
            text = text.isEmpty ? spoken : text + " " + spoken
        }
    }

    private func save() async {
        if voice.isRunning {
            await stopDictation()
        }

        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        // Write first, think later. Enrichment — titling, categorising, linking — happens
        // afterwards and patches this record. If the model is unavailable, or the app is
        // killed a second from now, the idea itself is already safe.
        let usedVoice = voice.finalizedText.isEmpty == false || autoStartVoice
        let idea = Idea(
            text: content,
            captureMode: usedVoice ? .voice : .text,
            transcriptRaw: usedVoice ? voice.finalizedText : nil
        )
        context.insert(idea)

        dismiss()
    }
}

private struct FailureNote: View {
    let message: String

    var body: some View {
        Text(message)
            .font(Theme.Typography.meta)
            .foregroundStyle(Theme.Palette.inkMuted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Theme.Space.lg)
            .padding(.bottom, Theme.Space.xs)
    }
}

#Preview {
    CaptureSheet()
        .modelContainer(try! RemliSchema.makeContainer(inMemory: true))
}
