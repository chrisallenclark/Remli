import SwiftData
import SwiftUI

struct IdeasListView: View {

    @Query(sort: \Idea.createdAt, order: .reverse)
    private var ideas: [Idea]

    @Environment(\.modelContext) private var context

    @State private var query = ""
    @State private var collection: SmartCollection = .all
    @State private var searchHits: [IdeaSearch.Hit] = []

    private let embeddings = EmbeddingService()

    private var collections: [SmartCollection] {
        SmartCollection.available(for: ideas)
    }

    /// Pinned ideas float to the top of every collection — a pin means "keep this in front
    /// of me", and honouring it only in one view would be a half-kept promise.
    private var visibleIdeas: [Idea] {
        guard query.isEmpty else { return searchResults }

        let filtered = ideas.filter { collection.matches($0) }
        return filtered.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned { return lhs.pinned }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private var searchResults: [Idea] {
        let byID = Dictionary(ideas.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return searchHits.compactMap { byID[$0.id] }
    }

    var body: some View {
        Group {
            if ideas.isEmpty {
                FirstRunView()
            } else {
                list
            }
        }
        .searchable(text: $query, prompt: "Search your ideas")
        .task(id: query) { await runSearch() }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Space.sm) {

                if query.isEmpty, collections.count > 1 {
                    CollectionChips(collections: collections, selection: $collection)
                }

                if visibleIdeas.isEmpty {
                    NoResultsView(query: query, collection: collection)
                        .padding(.top, Theme.Space.xl)
                } else {
                    ForEach(visibleIdeas) { idea in
                        NavigationLink {
                            IdeaDetailView(idea: idea)
                        } label: {
                            IdeaRowView(idea: idea)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                idea.pinned.toggle()
                                idea.touch()
                            } label: {
                                Label(
                                    idea.pinned ? "Unpin" : "Pin",
                                    systemImage: idea.pinned ? "pin.slash" : "pin"
                                )
                            }

                            Button(role: .destructive) {
                                context.delete(idea)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.top, Theme.Space.xs)
        }
        .scrollContentBackground(.hidden)
    }

    /// Semantic search needs the query embedded, which is cheap but not free, so it runs
    /// in a task keyed on the query rather than on every keystroke's render pass.
    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchHits = []
            return
        }

        let documents = ideas.map(IdeaSearch.Document.init)
        let vector = embeddings.vector(for: trimmed)
        searchHits = IdeaSearch.rank(query: trimmed, in: documents, queryVector: vector)
    }
}

private struct CollectionChips: View {
    let collections: [SmartCollection]
    @Binding var selection: SmartCollection

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.xs) {
                ForEach(collections) { collection in
                    let isSelected = collection == selection

                    Button {
                        withAnimation(Theme.Motion.standard) { selection = collection }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: collection.symbolName)
                                .font(.system(size: 10, weight: .medium))
                            Text(collection.label)
                                .font(Theme.Typography.meta)
                        }
                        .foregroundStyle(isSelected ? Theme.Palette.canvas : Theme.Palette.inkMuted)
                        .padding(.horizontal, Theme.Space.sm)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(isSelected ? Theme.Palette.ember : Theme.Palette.surface)
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                isSelected ? Color.clear : Theme.Palette.hairline,
                                lineWidth: 0.5
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .padding(.bottom, Theme.Space.xxs)
    }
}

private struct NoResultsView: View {
    let query: String
    let collection: SmartCollection

    var body: some View {
        VStack(spacing: Theme.Space.xs) {
            Text(query.isEmpty ? "Nothing in \(collection.label) yet" : "No matches")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.ink)

            if !query.isEmpty {
                Text("Remli searches meaning as well as words,\nso try describing the idea rather than naming it.")
                    .font(Theme.Typography.meta)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.inkMuted)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// The zero state.
///
/// Categories are emergent, so on day one there is genuinely nothing to show. Rather than
/// pretending otherwise with fake sample content, this says plainly what will happen once
/// there are a few ideas in here.
private struct FirstRunView: View {
    var body: some View {
        VStack(spacing: Theme.Space.md) {
            Spacer(minLength: Theme.Space.xxl)

            Image(systemName: "lightbulb.max")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.Palette.ember)

            Text("Nothing captured yet")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.ink)

            Text("Tap Capture the next time something occurs to you.\nRemli will title it, file it, and start finding\nthe threads between your ideas.")
                .font(Theme.Typography.meta)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.inkMuted)
                .lineSpacing(3)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Space.lg)
    }
}

#Preview {
    NavigationStack {
        IdeasListView()
            .background(Theme.Palette.canvas)
    }
    .modelContainer(try! RemliSchema.makeContainer(inMemory: true))
}
