import SwiftData
import SwiftUI

/// Review — the deliberate counterpart to notifications.
///
/// Notifications interrupt you with one idea. This is the place you come *on purpose*,
/// when you have time and want to choose something to work on. So it leads with what's
/// worth picking up rather than with what's newest.
struct ReviewView: View {

    @Query(sort: \Idea.createdAt, order: .reverse)
    private var ideas: [Idea]

    let coordinator: ResurfacingCoordinator?

    private var liveIdeas: [Idea] {
        ideas.filter { $0.status != .done && $0.kind == .idea }
    }

    /// Ranked by exactly the same scorer that drives notifications, so this screen and
    /// your nudges never disagree about what matters.
    private var worthRevisiting: [Idea] {
        let byID = Dictionary(liveIdeas.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ResurfacingScorer
            .rank(liveIdeas.map(ResurfacingCandidate.init), limit: 5)
            .compactMap { byID[$0.id] }
    }

    private var capturedThisWeek: [Idea] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return ideas.filter { $0.createdAt >= cutoff }
    }

    private var openTasks: [Idea] {
        ideas.filter { $0.kind == .task && $0.status != .done }
    }

    var body: some View {
        ZStack {
            Theme.Palette.canvas.ignoresSafeArea()

            if ideas.isEmpty {
                EmptyReviewView()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Space.lg) {
                        summary

                        if !worthRevisiting.isEmpty {
                            section("WORTH PICKING UP", ideas: worthRevisiting)
                        }

                        if !openTasks.isEmpty {
                            section("STILL TO DO", ideas: Array(openTasks.prefix(5)))
                        }
                    }
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.vertical, Theme.Space.md)
                }
            }
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.large)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            Text(summaryLine)
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(ideas.count) captured in total")
                .font(Theme.Typography.meta)
                .foregroundStyle(Theme.Palette.inkMuted)
        }
    }

    private var summaryLine: String {
        let count = capturedThisWeek.count
        switch count {
        case 0: return "Nothing new this week."
        case 1: return "One idea this week."
        default: return "\(count) ideas this week."
        }
    }

    private func section(_ title: String, ideas list: [Idea]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(title)
                .font(Theme.Typography.sectionLabel)
                .foregroundStyle(Theme.Palette.inkMuted)
                .tracking(0.6)

            ForEach(list) { idea in
                NavigationLink {
                    IdeaDetailView(idea: idea)
                        .onAppear { coordinator?.markSurfaced(ideaID: idea.id) }
                } label: {
                    IdeaRowView(idea: idea)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct EmptyReviewView: View {
    var body: some View {
        VStack(spacing: Theme.Space.sm) {
            Image(systemName: "calendar.day.timeline.left")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Theme.Palette.ember)

            Text("Nothing to review")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.ink)

            Text("Once you've captured a few ideas, this is where\nRemli shows you what's worth picking back up.")
                .font(Theme.Typography.meta)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.inkMuted)
                .lineSpacing(3)
        }
        .padding(Theme.Space.lg)
    }
}
