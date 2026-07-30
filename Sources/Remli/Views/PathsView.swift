import SwiftData
import SwiftUI

/// Paths — the routes through your ideas.
///
/// The map shows that ideas are related. This shows something stronger and more
/// actionable: that finishing one of them genuinely unlocks another. Only the directed
/// links take part, so a path here is a claim about order, not just about topic.
struct PathsView: View {

    @Query(sort: \Idea.createdAt, order: .reverse)
    private var ideas: [Idea]

    @State private var graph = IdeaGraph()
    @State private var chains: [[UUID]] = []

    private var ideasByID: [UUID: Idea] {
        Dictionary(ideas.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var body: some View {
        ZStack {
            Theme.Palette.canvas.ignoresSafeArea()

            if chains.isEmpty {
                NoPathsView(hasIdeas: !graph.isEmpty)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Space.xl) {
                        ForEach(Array(chains.enumerated()), id: \.offset) { _, chain in
                            ChainView(chain: chain, ideasByID: ideasByID)
                        }
                    }
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.vertical, Theme.Space.md)
                }
            }
        }
        .navigationTitle("Paths")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: ideas.count) { rebuild() }
    }

    private func rebuild() {
        graph = IdeaGraph(ideas: ideas)
        chains = graph.chains()
    }
}

/// One dependency chain, drawn top to bottom.
private struct ChainView: View {

    let chain: [UUID]
    let ideasByID: [UUID: Idea]

    private var steps: [Idea] {
        chain.compactMap { ideasByID[$0] }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text("\(steps.count) STEPS")
                .font(Theme.Typography.sectionLabel)
                .foregroundStyle(Theme.Palette.inkMuted)
                .tracking(0.6)

            ForEach(Array(steps.enumerated()), id: \.element.id) { index, idea in
                NavigationLink {
                    IdeaDetailView(idea: idea)
                } label: {
                    StepRow(
                        idea: idea,
                        index: index,
                        isLast: index == steps.count - 1
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct StepRow: View {

    let idea: Idea
    let index: Int
    let isLast: Bool

    private var accent: Color {
        idea.category.flatMap { Color(hex: $0.colorHex) } ?? Theme.Palette.ember
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.sm) {

            // The rail: a marker per step and a line continuing to the next, so the
            // sequence reads as a route rather than a list.
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(idea.status == .done ? accent : Theme.Palette.canvas)
                        .frame(width: 14, height: 14)
                    Circle()
                        .strokeBorder(accent, lineWidth: 1.5)
                        .frame(width: 14, height: 14)

                    if idea.status == .done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(Theme.Palette.canvas)
                    }
                }

                if !isLast {
                    Rectangle()
                        .fill(Theme.Palette.hairline)
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(idea.displayTitle)
                    .font(Theme.Typography.ideaBody)
                    .foregroundStyle(idea.status == .done ? Theme.Palette.inkMuted : Theme.Palette.ink)
                    .strikethrough(idea.status == .done, color: Theme.Palette.inkMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if index > 0 {
                    Text("unlocked by the step above")
                        .font(Theme.Typography.meta)
                        .foregroundStyle(Theme.Palette.inkMuted)
                }
            }
            .padding(.bottom, isLast ? 0 : Theme.Space.sm)

            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct NoPathsView: View {
    let hasIdeas: Bool

    var body: some View {
        VStack(spacing: Theme.Space.sm) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Theme.Palette.ember)

            Text("No paths yet")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.ink)

            Text(hasIdeas
                 ? "Paths appear when Remli spots that finishing\none idea would unlock another."
                 : "Capture a few ideas and Remli will start\nworking out which ones depend on which.")
                .font(Theme.Typography.meta)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.inkMuted)
                .lineSpacing(3)
        }
        .padding(Theme.Space.lg)
    }
}
