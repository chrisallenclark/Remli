import SwiftData
import SwiftUI

/// Text capture.
///
/// The design rule here is that nothing stands between having a thought and it being
/// saved. The field is focused on appear, there is no title field to fill in, no category
/// to choose and no tags to pick — all of that is the app's job afterwards, not the
/// user's beforehand.
struct CaptureSheet: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool { !trimmed.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                Theme.Palette.canvas.ignoresSafeArea()

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
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.Palette.inkMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear { isFocused = true }
    }

    private func save() {
        guard canSave else { return }

        // Write first, think later. Enrichment — titling, categorising, linking — happens
        // afterwards and patches this record. If the model is unavailable or the app is
        // killed a second from now, the idea itself is already safe.
        let idea = Idea(text: trimmed, captureMode: .text)
        context.insert(idea)

        dismiss()
    }
}

#Preview {
    CaptureSheet()
        .modelContainer(try! RemliSchema.makeContainer(inMemory: true))
}
