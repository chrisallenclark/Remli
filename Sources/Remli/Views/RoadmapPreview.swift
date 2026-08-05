import SwiftData
import SwiftUI

/// The roadmap an idea sits on, shown as a row of numbered steps.
///
/// A vertical chain is the honest way to read a long dependency path, but on the idea's own
/// screen the question is narrower and answerable at a glance: *where am I in this, and
/// what is next.* A horizontal stepper answers that in one line, and the tick marks say how
/// far along without anyone having to count.
///
/// Only shown when the idea is genuinely part of an ordered chain. An idea with no
/// prerequisites is not a project, and dressing one up as a five-step plan would be the
/// same invention the roadmap ordering rules exist to prevent.
struct RoadmapPreview: View {

    let idea: Idea

    @Query(sort: \Idea.createdAt, order: .reverse)
    private var allIdeas: [Idea]

    private var graph: IdeaGraph {
        IdeaGraph(ideas: allIdeas)
    }

    /// The longest chain this idea appears in. Longest because it is the most complete
    /// account of the route — a shorter chain through the same idea is a fragment of it.
    private var chain: [UUID] {
        let chains = graph.chains()
        var best: [UUID] = []
        for candidate in chains where candidate.contains(idea.id) {
            if candidate.count > best.count { best = candidate }
        }
        return best
    }

    private var steps: [Idea] {
        let byID = Dictionary(allIdeas.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return chain.compactMap { byID[$0] }
    }

    var body: some View {
        if steps.count >= 2 {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                HStack {
                    Label("Roadmap", systemImage: "arrow.triangle.branch")
                        .font(Theme.Typography.sectionLabel)
                        .foregroundStyle(Theme.Palette.inkMuted)
                        .tracking(0.6)

                    Spacer()

                    Text("\(completedCount) of \(steps.count) done")
                        .font(Theme.Typography.meta)
                        .foregroundStyle(Theme.Palette.inkMuted)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                            StepMarker(
                                step: step,
                                number: index + 1,
                                isCurrent: step.id == idea.id,
                                isLast: index == steps.count - 1
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardBackground()
        }
    }

    private var completedCount: Int {
        steps.filter { $0.status == .done }.count
    }
}

private struct StepMarker: View {

    let step: Idea
    let number: Int
    let isCurrent: Bool
    let isLast: Bool

    private var accent: Color {
        step.category.flatMap { Color(hex: $0.colorHex) } ?? Theme.Palette.ember
    }

    private var isDone: Bool { step.status == .done }

    var body: some View {
        VStack(spacing: Theme.Space.xxs) {
            HStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(isDone || isCurrent ? accent : Theme.Palette.surface)
                        .frame(width: 26, height: 26)

                    Circle()
                        .strokeBorder(
                            isDone || isCurrent ? Color.clear : Theme.Palette.hairline,
                            lineWidth: 1
                        )
                        .frame(width: 26, height: 26)

                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.Palette.canvas)
                    } else {
                        Text("\(number)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isCurrent ? Theme.Palette.canvas : Theme.Palette.inkMuted)
                    }
                }

                if !isLast {
                    // Dashed, because a step being *possible* after another is a claim
                    // about order, not a guarantee that anyone will walk it.
                    Rectangle()
                        .fill(Theme.Palette.hairline)
                        .frame(width: 34, height: 1)
                }
            }

            Text(step.displayTitle)
                .font(Theme.Typography.meta)
                .foregroundStyle(isCurrent ? Theme.Palette.ink : Theme.Palette.inkMuted)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 60)
                // The label sits under the marker, not under the connector, so the row of
                // circles stays evenly spaced regardless of how long the titles are.
                .padding(.trailing, isLast ? 0 : 34)
        }
    }
}
