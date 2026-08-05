import SwiftData
import SwiftUI

/// The daily sit-down.
///
/// Notifications interrupt you with one idea. This is the place you come *on purpose*, and
/// it has to be worth the trip on a day when you captured nothing — which is most days. So
/// it leads with what changed and what is waiting, not with a list of everything.
///
/// Every line here is derived from real state. There is no encouragement, no streak, no
/// "you're doing great": a screen that manufactures activity to seem alive is exactly the
/// thing that teaches people to stop opening it.
struct ReviewView: View {

    @Query(sort: \Idea.createdAt, order: .reverse)
    private var ideas: [Idea]

    let coordinator: ResurfacingCoordinator?

    @Environment(\.dismiss) private var dismiss

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

    /// Connections Remli has proposed that nobody has answered.
    private var pendingLinkCount: Int {
        var seen = Set<UUID>()
        for idea in ideas {
            for link in idea.allLinks where link.reviewState == .pending {
                seen.insert(link.id)
            }
        }
        return seen.count
    }

    private var capturedYesterday: Int {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: .now) else { return 0 }
        return ideas.filter { calendar.isDate($0.createdAt, inSameDayAs: yesterday) }.count
    }

    /// A finished idea whose successor has not been started. The most actionable thing the
    /// graph can say: you already did the hard part of something.
    private var unlockedNext: (done: Idea, next: Idea)? {
        let graph = IdeaGraph(ideas: ideas)
        let byID = Dictionary(ideas.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        for chain in graph.chains() where chain.count >= 2 {
            for index in 0..<(chain.count - 1) {
                guard
                    let current = byID[chain[index]],
                    let next = byID[chain[index + 1]],
                    current.status == .done,
                    next.status != .done
                else { continue }
                return (current, next)
            }
        }
        return nil
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 0..<5: return "Still up"
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var greetingSymbol: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 0..<5: return "moon.stars"
        case 5..<12: return "sun.horizon"
        case 12..<18: return "sun.max"
        default: return "moon"
        }
    }

    /// Counts you can act on, rather than a paragraph you skim.
    private var focusItems: [FocusItem] {
        var result: [FocusItem] = []

        if pendingLinkCount > 0 {
            result.append(FocusItem(
                symbol: "link",
                text: "\(pendingLinkCount) connection\(pendingLinkCount == 1 ? "" : "s") to look at"
            ))
        }

        let roadmaps = IdeaGraph(ideas: ideas).chains().count
        if roadmaps > 0 {
            result.append(FocusItem(
                symbol: "arrow.triangle.branch",
                text: "\(roadmaps) roadmap\(roadmaps == 1 ? "" : "s") in progress"
            ))
        }

        if !openTasks.isEmpty {
            result.append(FocusItem(
                symbol: "checkmark.circle",
                text: "\(openTasks.count) still to do"
            ))
        }

        return result
    }

    /// Only things that are true and specific to this library. An insight that could be
    /// printed for anyone on any day is noise wearing a nice font.
    private var insights: [InsightItem] {
        var result: [InsightItem] = []

        if let unlockedNext {
            result.append(InsightItem(
                symbol: "key",
                headline: "\"\(unlockedNext.done.displayTitle)\" is done",
                detail: "That clears the way for \"\(unlockedNext.next.displayTitle)\".",
                ideaID: unlockedNext.next.id
            ))
        }

        if capturedYesterday > 0 {
            result.append(InsightItem(
                symbol: "tray.and.arrow.down",
                headline: "You captured \(capturedYesterday) idea\(capturedYesterday == 1 ? "" : "s") yesterday",
                detail: nil,
                ideaID: nil
            ))
        }

        let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        if let stale = worthRevisiting.first(where: { $0.createdAt < monthAgo }) {
            result.append(InsightItem(
                symbol: "clock.arrow.circlepath",
                headline: "An older idea is worth another look",
                detail: "\"\(stale.displayTitle)\" from \(stale.createdAt.formatted(.dateTime.month(.abbreviated).day()))",
                ideaID: stale.id
            ))
        }

        return result
    }

    var body: some View {
        ZStack {
            Theme.Palette.canvas.ignoresSafeArea()

            if ideas.isEmpty {
                EmptyReviewView()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Space.lg) {
                        header

                        if !focusItems.isEmpty {
                            focus
                        }

                        if !insights.isEmpty {
                            insightSection
                        }

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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            HStack(alignment: .firstTextBaseline) {
                Text(greeting)
                    .font(Theme.Typography.display)
                    .foregroundStyle(Theme.Palette.ink)

                Spacer()

                Image(systemName: greetingSymbol)
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Theme.Palette.ember)
            }

            Text(summaryLine)
                .font(Theme.Typography.meta)
                .foregroundStyle(Theme.Palette.inkMuted)
        }
    }

    private var summaryLine: String {
        let count = capturedThisWeek.count
        let total = "\(ideas.count) captured in total"
        switch count {
        case 0: return "Nothing new this week · \(total)"
        case 1: return "One idea this week · \(total)"
        default: return "\(count) ideas this week · \(total)"
        }
    }

    private var focus: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text("TODAY'S FOCUS")
                .font(Theme.Typography.sectionLabel)
                .foregroundStyle(Theme.Palette.inkMuted)
                .tracking(0.6)

            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                ForEach(focusItems) { item in
                    HStack(spacing: Theme.Space.xs) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.Palette.ember)
                            .frame(width: 18)

                        Text(item.text)
                            .font(Theme.Typography.ideaBody)
                            .foregroundStyle(Theme.Palette.ink)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardBackground()
        }
    }

    private var insightSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text("INSIGHTS")
                .font(Theme.Typography.sectionLabel)
                .foregroundStyle(Theme.Palette.inkMuted)
                .tracking(0.6)

            ForEach(insights) { insight in
                if let ideaID = insight.ideaID, let idea = ideas.first(where: { $0.id == ideaID }) {
                    NavigationLink {
                        IdeaDetailView(idea: idea)
                    } label: {
                        InsightCard(insight: insight)
                    }
                    .buttonStyle(.plain)
                } else {
                    InsightCard(insight: insight)
                }
            }
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

/// One line in Today's Focus.
private struct FocusItem: Identifiable {
    var id: String { symbol + text }
    let symbol: String
    let text: String
}

/// One observation, optionally pointing at the idea it is about.
private struct InsightItem: Identifiable {
    let id = UUID()
    let symbol: String
    let headline: String
    let detail: String?
    let ideaID: UUID?
}

private struct InsightCard: View {
    let insight: InsightItem

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            HStack(alignment: .top, spacing: Theme.Space.xs) {
                Image(systemName: insight.symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Palette.ember)
                    .frame(width: 18)

                Text(insight.headline)
                    .font(Theme.Typography.ideaBody)
                    .foregroundStyle(Theme.Palette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let detail = insight.detail {
                Text(detail)
                    .font(Theme.Typography.meta)
                    .foregroundStyle(Theme.Palette.inkMuted)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 18 + Theme.Space.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
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
