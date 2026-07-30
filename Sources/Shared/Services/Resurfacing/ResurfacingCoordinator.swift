import BackgroundTasks
import Foundation
import Observation
import SwiftData

/// Ties the store, the scorer and the scheduler together.
///
/// Runs on launch and from a background refresh task. Rebuilding the whole schedule each
/// time is intentional — see `NotificationScheduler.reschedule`.
@MainActor
@Observable
final class ResurfacingCoordinator {

    /// Must also appear in `BGTaskSchedulerPermittedIdentifiers` in Info.plist, or
    /// registration throws at launch.
    static let refreshTaskIdentifier = "com.chrisallenclark.remli.refresh"

    private let context: ModelContext
    private let settingsStore: ResurfacingSettingsStore
    private let scheduler = NotificationScheduler()
    private let calendarReader = CalendarBusyReader()

    private(set) var lastRefresh: Date?

    init(context: ModelContext, settingsStore: ResurfacingSettingsStore) {
        self.context = context
        self.settingsStore = settingsStore
    }

    var settings: ResurfacingSettings { settingsStore.settings }

    // MARK: - The main pass

    func refresh() async {
        let settings = settingsStore.settings
        guard settings.hasAnythingEnabled else {
            await scheduler.clear()
            return
        }

        let ideas = fetchLiveIdeas()

        let ranked = ResurfacingScorer.rank(ideas.map(ResurfacingCandidate.init), limit: 60)
        let titlesByID = Dictionary(ideas.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let planned: [NotificationScheduler.PlannedIdea] = ranked.compactMap { candidate in
            guard let idea = titlesByID[candidate.id] else { return nil }
            return NotificationScheduler.PlannedIdea(
                id: idea.id,
                title: idea.displayTitle,
                estimatedMinutes: idea.estimatedMinutes
            )
        }

        let reminders: [(idea: NotificationScheduler.PlannedIdea, date: Date)] = ideas.compactMap { idea in
            guard let remindAt = idea.remindAt, remindAt > .now else { return nil }
            return (
                NotificationScheduler.PlannedIdea(
                    id: idea.id,
                    title: idea.displayTitle,
                    estimatedMinutes: idea.estimatedMinutes
                ),
                remindAt
            )
        }

        let gaps = settings.freeTimeEnabled ? upcomingGaps(settings: settings) : []

        await scheduler.reschedule(
            ideas: planned,
            explicitReminders: reminders,
            gaps: gaps,
            settings: settings
        )

        lastRefresh = .now
    }

    private func fetchLiveIdeas() -> [Idea] {
        let doneRaw = IdeaStatus.done.rawValue
        let descriptor = FetchDescriptor<Idea>(
            predicate: #Predicate { $0.statusRaw != doneRaw },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Free windows over the next two days. Beyond that a calendar changes too much for a
    /// suggestion to still be right by the time it fires.
    private func upcomingGaps(settings: ResurfacingSettings) -> [TimeGap] {
        guard calendarReader.isAuthorized else { return [] }

        let calendar = Calendar.current
        var gaps: [TimeGap] = []

        for dayOffset in 0...1 {
            guard
                let day = calendar.date(byAdding: .day, value: dayOffset, to: .now),
                let window = FreeTimeFinder.wakingWindow(
                    on: day,
                    startHour: settings.dayStartHour,
                    endHour: settings.dayEndHour
                )
            else { continue }

            // Never suggest a window that has already begun — arriving mid-gap makes the
            // stated duration wrong.
            let effective = DateInterval(start: max(window.start, .now), end: window.end)
            guard effective.duration > 0 else { continue }

            let busy = calendarReader.busyIntervals(in: effective)
            gaps.append(
                contentsOf: FreeTimeFinder.gaps(
                    busy: busy,
                    within: effective,
                    minimumMinutes: settings.freeTimeMinimumMinutes
                )
            )
        }

        return gaps
    }

    // MARK: - Feedback

    /// Records that an idea was actually put in front of the user, which feeds the
    /// novelty and staleness terms so the same idea isn't shown repeatedly.
    func markSurfaced(ideaID: UUID) {
        let descriptor = FetchDescriptor<Idea>(predicate: #Predicate { $0.id == ideaID })
        guard let idea = (try? context.fetch(descriptor))?.first else { return }
        idea.lastSurfacedAt = .now
        idea.surfaceCount += 1
        try? context.save()
    }

    // MARK: - Permissions

    func enableNotifications() async -> Bool {
        await scheduler.requestAuthorization()
    }

    var authorizationIsGranted: Bool {
        get async { await scheduler.authorizationStatus == .authorized }
    }

    /// Which engine is actually filing ideas, so Settings can say so plainly rather than
    /// leaving the user to guess why results changed.
    var engineDescription: String {
        FoundationModelsIntelligence().isAvailable
            ? FoundationModelsIntelligence().displayName
            : HeuristicIntelligence().displayName
    }

    func enableCalendarAccess() async -> Bool {
        await calendarReader.requestAccess()
    }

    var isCalendarAuthorized: Bool { calendarReader.isAuthorized }

    // MARK: - Background refresh

    /// Registered once, at launch, before the app finishes launching.
    ///
    /// `nonisolated` so it can be called from `App.init`, which is not main-actor isolated.
    nonisolated static func registerBackgroundTask(handler: @escaping @Sendable () async -> Void) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: refreshTaskIdentifier,
            using: nil
        ) { task in
            // Always reschedule first. If this pass crashes or expires, a missing
            // follow-up would silently end all future background refreshes.
            scheduleBackgroundRefresh()

            let work = Task {
                await handler()
                task.setTaskCompleted(success: true)
            }

            task.expirationHandler = {
                work.cancel()
                task.setTaskCompleted(success: false)
            }
        }
    }

    nonisolated static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        // A hint, not a promise — iOS decides when this actually runs based on usage.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }
}
