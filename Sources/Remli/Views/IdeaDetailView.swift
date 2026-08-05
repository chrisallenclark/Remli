import SwiftData
import SwiftUI

struct IdeaDetailView: View {

    @Bindable var idea: Idea

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var isMovingToSpace = false

    /// The text as it was when this screen opened, so an edit can be detected on the way
    /// out without watching every keystroke.
    @State private var textWhenOpened: String?

    private let embeddings = EmbeddingService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {

                header

                if isEditing {
                    TextEditor(text: $idea.text)
                        .font(Theme.Typography.ideaBody)
                        .foregroundStyle(Theme.Palette.ink)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 220)
                        .cardBackground()
                        .onChange(of: idea.text) { _, _ in idea.touch() }
                } else {
                    Text(idea.text)
                        .font(Theme.Typography.ideaBody)
                        .foregroundStyle(Theme.Palette.ink)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }

                if !idea.tags.isEmpty {
                    TagRow(tags: idea.tags)
                }

                ConnectionsSection(idea: idea)

                RoadmapPreview(idea: idea)

                statusControl

                Spacer(minLength: Theme.Space.xxl)
            }
            .padding(.horizontal, Theme.Space.lg)
            .padding(.top, Theme.Space.md)
        }
        .background(Theme.Palette.canvas)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        isEditing.toggle()
                    } label: {
                        Label(isEditing ? "Done editing" : "Edit", systemImage: "pencil")
                    }

                    Button {
                        idea.pinned.toggle()
                        idea.touch()
                    } label: {
                        Label(idea.pinned ? "Unpin" : "Pin", systemImage: idea.pinned ? "pin.slash" : "pin")
                    }

                    Button {
                        isMovingToSpace = true
                    } label: {
                        Label("Move to a Space…", systemImage: "square.stack.3d.up")
                    }

                    Divider()

                    Button(role: .destructive) {
                        context.delete(idea)
                        dismiss()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isMovingToSpace) {
            SpacePickerView(idea: idea)
        }
        .onAppear { textWhenOpened = idea.text }
        .onDisappear(perform: reindexIfEdited)
    }

    /// Recomputes the search vector when the text has actually changed.
    ///
    /// The embedding is written once during enrichment and was never touched again, so an
    /// idea you rewrote last week was still being found — or not found — on the strength of
    /// what it used to say. Nothing visibly broke, which is what made it worth fixing:
    /// semantic search quietly drifted away from the words on the screen.
    ///
    /// Done on the way out rather than per keystroke. `NLEmbedding` is on-device and fast,
    /// but it is not free, and the only moment the result matters is after the edit is
    /// finished.
    private func reindexIfEdited() {
        guard let before = textWhenOpened, before != idea.text else { return }

        if let vector = embeddings.vector(for: idea) {
            idea.embedding = VectorCodec.encode(vector)
        } else {
            // No vector available on this device — better to drop the stale one than to
            // keep matching against text that no longer exists. Literal search still works.
            idea.embedding = nil
        }

        textWhenOpened = idea.text
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(idea.displayTitle)
                .font(Theme.Typography.display)
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Space.xs) {
                // The chip is the control. Filing is something you reconsider while looking
                // at the idea, so the affordance belongs on the thing that shows where it
                // currently lives rather than buried in the overflow menu — which also
                // still offers it, for when the idea has no Space to tap.
                Button {
                    isMovingToSpace = true
                } label: {
                    if let category = idea.category {
                        CategoryChip(category: category, showsPath: true)
                    } else {
                        Label("Add to a Space", systemImage: "square.stack.3d.up")
                            .font(Theme.Typography.meta)
                            .foregroundStyle(Theme.Palette.inkMuted)
                    }
                }
                .buttonStyle(.plain)

                Text(idea.createdAt, format: .dateTime.day().month(.abbreviated).hour().minute())
                    .font(Theme.Typography.meta)
                    .foregroundStyle(Theme.Palette.inkMuted)
            }
        }
    }

    private var statusControl: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text("STATUS")
                .font(Theme.Typography.sectionLabel)
                .foregroundStyle(Theme.Palette.inkMuted)
                .tracking(0.6)

            Picker("Status", selection: Binding(
                get: { idea.status },
                set: { idea.status = $0; idea.touch() }
            )) {
                ForEach(IdeaStatus.allCases, id: \.self) { status in
                    Text(status.label).tag(status)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

struct TagRow: View {
    let tags: [String]

    var body: some View {
        // A simple wrapping row. Tags are short by construction, so a flow layout is
        // overkill here.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.xs) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(Theme.Typography.meta)
                        .foregroundStyle(Theme.Palette.inkMuted)
                        .padding(.horizontal, Theme.Space.xs)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.Palette.hairline))
                }
            }
        }
    }
}
