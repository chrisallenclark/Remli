import SwiftData
import SwiftUI

/// All your Spaces, as a grid of places.
///
/// The Ideas list answers "what have I thought"; this answers "what am I working on". They
/// are different questions and deserve different screens — which is why this is a grid of
/// large, coloured tiles rather than another list. A Space should be recognisable before
/// you read its name.
///
/// The tiles are generated, not photographed. Real imagery would look better for the six
/// Spaces someone might name today and fall apart on the seventh, because there is no
/// picture for "Hybrid Performance" that the app can know about. A gradient built from the
/// Space's own colour is always right, always distinct, and costs nothing to sync.
struct SpacesView: View {

    @Query(sort: \IdeaCategory.name)
    private var allPlaces: [IdeaCategory]

    @Environment(\.modelContext) private var context

    @State private var isNaming = false
    @State private var newName = ""
    @FocusState private var nameFocused: Bool

    private var spaces: [IdeaCategory] {
        // Busiest first: a Space you are actually using should not sit below one the model
        // invented once and never filled.
        allPlaces
            .filter(\.isSpace)
            .sorted { lhs, rhs in
                if lhs.totalIdeaCount == rhs.totalIdeaCount {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                return lhs.totalIdeaCount > rhs.totalIdeaCount
            }
    }

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Space.sm),
        GridItem(.flexible(), spacing: Theme.Space.sm),
    ]

    var body: some View {
        ScrollView {
            if spaces.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: Theme.Space.sm) {
                    ForEach(spaces) { space in
                        NavigationLink {
                            SpaceView(space: space)
                        } label: {
                            SpaceTile(space: space)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Space.md)
                .padding(.top, Theme.Space.xs)
            }

            newSpaceControl
                .padding(.horizontal, Theme.Space.md)
                .padding(.top, Theme.Space.sm)

            Spacer(minLength: Theme.Space.xxl)
        }
        .background(Theme.Palette.canvas)
        .navigationTitle("Spaces")
    }

    private var newSpaceControl: some View {
        Group {
            if isNaming {
                HStack(spacing: Theme.Space.xs) {
                    TextField("Name this Space", text: $newName)
                        .font(Theme.Typography.ideaBody)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit(commit)

                    Button("Add", action: commit)
                        .font(Theme.Typography.control)
                        .disabled(trimmedName.isEmpty)
                }
                .padding(Theme.Space.sm)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .fill(Theme.Palette.surface)
                )
            } else {
                Button {
                    newName = ""
                    isNaming = true
                    nameFocused = true
                } label: {
                    Label("New Space", systemImage: "plus")
                        .font(Theme.Typography.control)
                        .foregroundStyle(Theme.Palette.inkMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Space.sm)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .strokeBorder(Theme.Palette.hairline, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var trimmedName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func commit() {
        let name = trimmedName
        guard !name.isEmpty else {
            isNaming = false
            return
        }

        let normalized = name.lowercased()
        if !spaces.contains(where: { $0.name.lowercased() == normalized }) {
            let space = IdeaCategory(
                name: name,
                symbolName: "square.stack.3d.up",
                isUserOwned: true
            )
            context.insert(space)
        }

        newName = ""
        isNaming = false
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.sm) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.Palette.ember)

            Text("No Spaces yet")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.ink)

            Text("Capture a few ideas and Remli will start\nsorting them into Spaces. You can make\nyour own at any time.")
                .font(Theme.Typography.meta)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.inkMuted)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Space.xxl)
        .padding(.horizontal, Theme.Space.lg)
    }
}

/// One Space as a tile.
private struct SpaceTile: View {
    let space: IdeaCategory

    private var accent: Color {
        Color(hex: space.colorHex) ?? Theme.Palette.ember
    }

    private var subtitle: String {
        let count = space.totalIdeaCount
        return "\(count) \(count == 1 ? "idea" : "ideas")"
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Two gradients: a diagonal wash for depth, and a soft bloom in the top corner
            // so the tile looks lit from somewhere rather than merely filled.
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.55), accent.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.18), .clear],
                                center: .topTrailing,
                                startRadius: 0,
                                endRadius: 140
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
                )

            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: space.symbolName)
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.bottom, Theme.Space.xs)

                Text(space.name)
                    .font(Theme.Typography.title)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(Theme.Typography.meta)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(Theme.Space.sm)
        }
        .frame(height: 150)
    }
}
