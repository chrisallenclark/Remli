import SwiftData
import SwiftUI

/// One Space, as a place rather than a filter.
///
/// The Ideas list is deliberately neutral — every idea you have, one typeface, one ground,
/// nothing shouting. That neutrality is right for capture and wrong for thinking inside a
/// single area of your life, where the point is that Macrova should not feel like Music.
///
/// So this is the one screen that takes on a colour. The ground shifts toward the Space's
/// own hue and a soft wash sits behind the title; everything else — the type, the spacing,
/// the rows — is exactly what the rest of the app uses. Visual complexity rises when you
/// enter a Space and drops back the moment you leave, which is the only way it stays a
/// signal rather than decoration.
struct SpaceView: View {

    let space: IdeaCategory

    @Query(sort: \Idea.createdAt, order: .reverse)
    private var allIdeas: [Idea]

    /// Nil means "everything in this Space"; otherwise a Collection inside it.
    @State private var focusedCollection: IdeaCategory?

    private var accent: Color {
        Color(hex: space.colorHex) ?? Theme.Palette.ember
    }

    private var collections: [IdeaCategory] {
        space.sortedChildren
    }

    /// Ideas filed directly in the Space plus everything in its Collections — filtered
    /// down when a Collection is focused.
    private var ideas: [Idea] {
        let collectionIDs = Set(collections.map(\.id))

        var result: [Idea] = []
        for idea in allIdeas {
            guard let place = idea.category else { continue }

            if let focusedCollection {
                if place.id == focusedCollection.id { result.append(idea) }
                continue
            }

            if place.id == space.id || collectionIDs.contains(place.id) {
                result.append(idea)
            }
        }

        // Pinned first, newest next — the same promise the main list makes.
        result.sort { lhs, rhs in
            if lhs.pinned != rhs.pinned { return lhs.pinned }
            return lhs.createdAt > rhs.createdAt
        }
        return result
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Space.sm) {
                header

                if !collections.isEmpty {
                    collectionChips
                }

                if ideas.isEmpty {
                    emptyState
                } else {
                    ForEach(ideas) { idea in
                        NavigationLink {
                            IdeaDetailView(idea: idea)
                        } label: {
                            IdeaRowView(idea: idea)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: Theme.Space.xxl)
            }
            .padding(.horizontal, Theme.Space.md)
        }
        .background(ground)
        .navigationTitle(space.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - The environment

    /// Canvas, tinted. Kept at a low opacity on purpose: enough that two Spaces are
    /// unmistakably different rooms, not so much that idea text loses contrast against it.
    private var ground: some View {
        ZStack {
            Theme.Palette.canvas

            LinearGradient(
                colors: [accent.opacity(0.16), accent.opacity(0.03), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            Image(systemName: space.symbolName)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(accent)
                .padding(.bottom, Theme.Space.xxs)

            Text(space.name)
                .font(Theme.Typography.display)
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(summary)
                .font(Theme.Typography.meta)
                .foregroundStyle(Theme.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.Space.md)
        .padding(.bottom, Theme.Space.sm)
    }

    private var summary: String {
        let ideaCount = space.totalIdeaCount
        let ideaWord = ideaCount == 1 ? "idea" : "ideas"

        guard !collections.isEmpty else { return "\(ideaCount) \(ideaWord)" }

        let collectionWord = collections.count == 1 ? "collection" : "collections"
        return "\(ideaCount) \(ideaWord) · \(collections.count) \(collectionWord)"
    }

    private var collectionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.xs) {
                chip(label: "All", isSelected: focusedCollection == nil) {
                    focusedCollection = nil
                }

                ForEach(collections) { collection in
                    chip(
                        label: collection.name,
                        isSelected: focusedCollection?.id == collection.id
                    ) {
                        // Tapping the focused Collection again clears it, so there is
                        // always a way back out without hunting for "All".
                        focusedCollection = focusedCollection?.id == collection.id ? nil : collection
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .padding(.bottom, Theme.Space.xxs)
    }

    private func chip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Theme.Motion.standard) { action() }
        } label: {
            Text(label)
                .font(Theme.Typography.meta)
                .foregroundStyle(isSelected ? Theme.Palette.canvas : Theme.Palette.inkMuted)
                .padding(.horizontal, Theme.Space.sm)
                .padding(.vertical, 6)
                .background(Capsule().fill(isSelected ? accent : Theme.Palette.surface))
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? Color.clear : Theme.Palette.hairline,
                        lineWidth: 0.5
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.xs) {
            Text(focusedCollection == nil
                 ? "Nothing in this Space yet"
                 : "Nothing in this Collection yet")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.ink)

            Text("Ideas land here when Remli files them,\nor when you move one in yourself.")
                .font(Theme.Typography.meta)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.inkMuted)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Space.xl)
    }
}
