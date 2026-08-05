import SwiftData
import SwiftUI

/// Roadmaps — the routes through your ideas.
///
/// The map shows that ideas are related. This shows something stronger and much easier to
/// get wrong: that finishing one of them genuinely makes another possible. Only
/// `prerequisiteFor` links above a confidence bar take part, and every step shows the
/// sentence the model wrote to justify the order — because a roadmap you cannot argue with
/// is a roadmap you cannot trust.
struct RoadmapsView: View {

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
                NoRoadmapsView(hasIdeas: !graph.isEmpty)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Space.xl) {
                        ForEach(Array(chains.enumerated()), id: \.offset) { _, chain in
                            ChainView(chain: chain, ideasByID: ideasByID, graph: graph)
                        }
                    }
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.vertical, Theme.Space.md)
                }
            }
        }
        .navigationTitle("Roadmaps")
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
    let graph: IdeaGraph

    private var steps: [Idea] {
        chain.compactMap { ideasByID[$0] }
    }

    /// The written reason each step follows the one above it. Index 0 has no predecessor,
    /// so it has no reason — which is why this is looked up per step rather than zipped.
    private func reason(forStepAt index: Int) -> String? {
        guard index > 0, index < chain.count else { return nil }
        let edge = graph.orderingEdge(from: chain[index - 1], to: chain[index])
        let rationale = edge?.rationale.trimmingCharacters(in: .whitespacesAndNewlines)
        return (rationale?.isEmpty == false) ? rationale : nil
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
                        isLast: index == steps.count - 1,
                        reason: reason(forStepAt: index)
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
    /// Why this step follows the previous one. Nil for the first step, and for any link
    /// the model produced without a usable explanation.
    let reason: String?

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

                // The model's own justification, verbatim. "Unlocked by the step above"
                // said nothing and asked to be believed; this can be read and disagreed
                // with, which is the only way a claim about order earns any trust.
                if let reason {
                    Text(reason)
                        .font(Theme.Typography.meta)
                        .foregroundStyle(Theme.Palette.inkMuted)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.bottom, isLast ? 0 : Theme.Space.sm)

            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct NoRoadmapsView: View {
    let hasIdeas: Bool

    var body: some View {
        VStack(spacing: Theme.Space.sm) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Theme.Palette.ember)

            Text("No roadmaps yet")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.ink)

            Text(hasIdeas
                 ? "A roadmap appears when Remli is confident that\nfinishing one idea genuinely makes another possible.\nRelated ideas alone aren't enough."
                 : "Capture a few ideas and Remli will start\nworking out which ones depend on which.")
                .font(Theme.Typography.meta)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.inkMuted)
                .lineSpacing(3)
        }
        .padding(Theme.Space.lg)
    }
}
