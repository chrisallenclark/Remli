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
        SmartCollection.available(for: ideas.filter { !$0.isRoadmapStep })
    }

    /// Pinned ideas float to the top of every collection — a pin means "keep this in front
    /// of me", and honouring it only in one view would be a half-kept promise.
    private var visibleIdeas: [Idea] {
        guard query.isEmpty else { return searchResults }

        // Roadmap steps are deliberately absent. They live on their roadmap; showing them
        // here turns the Ideas list into a task list and buries the actual ideas.
        let filtered = ideas.filter { !$0.isRoadmapStep && collection.matches($0) }
        return filtered.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned { return lhs.pinned }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private var searchResults: [Idea] {
        let byID = Dictionary(ideas.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return searchHits.compactMap { byID[$0.id] }
    }

    /// The Space behind the selected chip, when the selection is a Space rather than a
    /// Collection or one of the fixed views. Resolved through an idea because the chips
    /// carry only an id and a name.
    private var selectedSpace: IdeaCategory? {
        guard case .category(let id, _, let isCollection) = collection, !isCollection else {
            return nil
        }
        for idea in ideas {
            if let place = idea.category {
                if place.id == id { return place }
                if let parent = place.parent, parent.id == id { return parent }
            }
        }
        return nil
    }

    /// Why each result is in the list, keyed by idea. Empty when not searching.
    private var reasonsByID: [UUID: IdeaSearch.MatchReason] {
        var result: [UUID: IdeaSearch.MatchReason] = [:]
        for hit in searchHits {
            result[hit.id] = hit.reason
        }
        return result
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

                // The way into a Space, offered only once you have picked one. Putting a
                // permanent list of Spaces above every idea would make the first screen
                // about organisation, when it should be about what you thought.
                if let space = selectedSpace {
                    NavigationLink {
                        SpaceView(space: space)
                    } label: {
                        EnterSpaceCard(space: space)
                    }
                    .buttonStyle(.plain)
                }

                if visibleIdeas.isEmpty {
                    NoResultsView(query: query, collection: collection)
                        .padding(.top, Theme.Space.xl)
                } else {
                    ForEach(visibleIdeas) { idea in
                        NavigationLink {
                            IdeaDetailView(idea: idea)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                IdeaRowView(idea: idea)

                                // Only while searching. A result found by meaning shares
                                // none of your words, which looks like a bug until the row
                                // says so — and knowing *how* something matched is the
                                // quickest way to tell a real hit from a lucky one.
                                if let reason = reasonsByID[idea.id] {
                                    MatchReasonLabel(reason: reason)
                                }
                            }
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

        let documents = ideas.filter { !$0.isRoadmapStep }.map(IdeaSearch.Document.init)
        let vector = embeddings.vector(for: trimmed)
        searchHits = IdeaSearch.rank(query: trimmed, in: documents, queryVector: vector)
    }
}

/// The doorway into a Space, shown above the filtered list.
private struct EnterSpaceCard: View {
    let space: IdeaCategory

    private var accent: Color {
        Color(hex: space.colorHex) ?? Theme.Palette.ember
    }

    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            Image(systemName: space.symbolName)
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 1) {
                Text("Enter \(space.name)")
                    .font(Theme.Typography.control)
                    .foregroundStyle(Theme.Palette.ink)

                Text(space.sortedChildren.isEmpty
                     ? "See this Space on its own"
                     : "\(space.sortedChildren.count) collections inside")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(Theme.Palette.inkMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Palette.inkMuted)
        }
        .padding(Theme.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(accent.opacity(0.22), lineWidth: 0.5)
        )
        .padding(.bottom, Theme.Space.xxs)
    }
}

/// A one-line note under a search result saying how it was found.
private struct MatchReasonLabel: View {
    let reason: IdeaSearch.MatchReason

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: reason.symbolName)
                .font(.system(size: 9, weight: .medium))
            Text(reason.label)
                .font(Theme.Typography.meta)
        }
        .foregroundStyle(Theme.Palette.inkMuted)
        .padding(.leading, Theme.Space.xs)
        .padding(.bottom, Theme.Space.xxs)
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
