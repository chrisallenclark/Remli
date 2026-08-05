import Foundation
import UserNotifications

/// Schedules the notifications that bring ideas back.
///
/// The constraint shaping everything here: **iOS keeps at most 64 pending local
/// notifications per app**, and silently drops the rest. Local notifications also need
/// their content decided when they are scheduled, not when they fire — so Remli plans a
/// rolling window ahead and rebuilds it whenever the app runs.
///
/// That means the window length is derived from the budget rather than fixed. Someone with
/// six nudge times a day gets fewer days planned ahead than someone with one; both stay
/// inside 64 and neither silently loses notifications.
@MainActor
final class NotificationScheduler {

    /// The hard iOS limit. Left a little headroom rather than filling it exactly.
    private static let budget = 60

    /// Prefix on every identifier Remli creates, so clearing our schedule never touches
    /// anything else.
    private static let prefix = "remli."

    enum Category: String {
        case dailyNudge = "remli.daily"
        case freeTime = "remli.freetime"
        case reminder = "remli.reminder"
        case weeklyReview = "remli.weekly"
    }

    struct PlannedIdea: Sendable {
        var id: UUID
        var title: String
        var estimatedMinutes: Int
    }

    private let center = UNUserNotificationCenter.current()

    // MARK: - Authorisation

    var authorizationStatus: UNAuthorizationStatus {
        get async { await center.notificationSettings().authorizationStatus }
    }

    /// Asked for only when the user turns resurfacing on — never at launch. A permission
    /// prompt with no context is one that gets declined.
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Scheduling

    /// Replaces Remli's entire pending schedule.
    ///
    /// Rebuilding wholesale rather than patching is the only way to keep the plan
    /// consistent: ideas get captured, completed and re-scored between runs, and a
    /// notification about an idea finished yesterday is exactly the kind of thing that
    /// makes people stop trusting an app's notifications.
    func reschedule(
        ideas: [PlannedIdea],
        explicitReminders: [(idea: PlannedIdea, date: Date)],
        gaps: [TimeGap],
        settings: ResurfacingSettings,
        now: Date = .now
    ) async {
        await clear()

        guard settings.hasAnythingEnabled else { return }
        guard await authorizationStatus == .authorized else { return }

        var remaining = Self.budget
        var requests: [UNNotificationRequest] = []

        // 1. Explicit per-idea reminders. The user asked for these by name, so they win
        //    any competition for budget.
        for entry in explicitReminders where entry.date > now {
            guard remaining > 0 else { break }
            requests.append(reminderRequest(idea: entry.idea, at: entry.date))
            remaining -= 1
        }

        // 2. Free-time suggestions, capped so a busy week cannot crowd out everything else.
        if settings.freeTimeEnabled {
            let cap = min(remaining, 8)
            for gap in gaps.prefix(cap) {
                guard remaining > 0 else { break }
                guard let idea = bestIdea(for: gap, from: ideas) else { continue }
                requests.append(freeTimeRequest(idea: idea, gap: gap))
                remaining -= 1
            }
        }

        // 3. Weekly review.
        if settings.weeklyReviewEnabled, remaining > 0 {
            requests.append(weeklyReviewRequest(settings: settings))
            remaining -= 1
        }

        // 4. Daily nudges fill whatever is left, spread over as many days as fit.
        if settings.dailyNudgesEnabled, !settings.dailyTimes.isEmpty, !ideas.isEmpty, remaining > 0 {
            requests.append(
                contentsOf: dailyNudgeRequests(
                    ideas: ideas,
                    settings: settings,
                    budget: remaining,
                    now: now
                )
            )
        }

        for request in requests {
            try? await center.add(request)
        }
    }

    func clear() async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
    }

    // MARK: - Builders

    private func bestIdea(for gap: TimeGap, from ideas: [PlannedIdea]) -> PlannedIdea? {
        // Fits the window, and uses as much of it as possible.
        ideas
            .filter { $0.estimatedMinutes > 0 && $0.estimatedMinutes <= gap.minutes }
            .max { $0.estimatedMinutes < $1.estimatedMinutes }
    }

    private func reminderRequest(idea: PlannedIdea, at date: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "You wanted a nudge about this"
        content.body = idea.title
        content.sound = .default
        content.userInfo = ["ideaID": idea.id.uuidString]
        content.categoryIdentifier = Category.reminder.rawValue

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )

        return UNNotificationRequest(
            identifier: "\(Self.prefix)reminder.\(idea.id.uuidString)",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
    }

    private func freeTimeRequest(idea: PlannedIdea, gap: TimeGap) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "\(gap.minutes) minutes free"
        content.body = "Good window for: \(idea.title)"
        content.sound = .default
        content.userInfo = ["ideaID": idea.id.uuidString]
        content.categoryIdentifier = Category.freeTime.rawValue

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: gap.start
        )

        return UNNotificationRequest(
            identifier: "\(Self.prefix)freetime.\(Int(gap.start.timeIntervalSince1970))",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
    }

    private func weeklyReviewRequest(settings: ResurfacingSettings) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Your week in ideas"
        content.body = "A few things worth a second look."
        content.sound = .default
        content.categoryIdentifier = Category.weeklyReview.rawValue

        var components = DateComponents()
        components.weekday = settings.weeklyReviewWeekday
        components.hour = settings.weeklyReviewHour
        components.minute = 0

        return UNNotificationRequest(
            identifier: "\(Self.prefix)weekly",
            content: content,
            // The one repeating trigger in the app: its content is generic, so unlike the
            // per-idea notifications it does not go stale between rebuilds.
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
    }

    private func dailyNudgeRequests(
        ideas: [PlannedIdea],
        settings: ResurfacingSettings,
        budget: Int,
        now: Date
    ) -> [UNNotificationRequest] {
        let times = settings.dailyTimes.sorted()
        let calendar = Calendar.current

        // How many days ahead can be planned without exceeding what's left of the budget.
        let daysAhead = max(1, min(14, budget / max(1, times.count)))

        var requests: [UNNotificationRequest] = []
        var ideaIndex = 0

        for dayOffset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }

            for time in times {
                guard requests.count < budget else { return requests }
                guard
                    let fireDate = calendar.date(
                        bySettingHour: time.hour,
                        minute: time.minute,
                        second: 0,
                        of: day
                    ),
                    fireDate > now
                else { continue }

                // Different idea each time, cycling. Being shown the same thought at 9am
                // and 2pm would read as a bug.
                let idea = ideas[ideaIndex % ideas.count]
                ideaIndex += 1

                let content = UNMutableNotificationContent()
                content.title = "Remember this?"
                content.body = idea.title
                content.sound = .default
                content.userInfo = ["ideaID": idea.id.uuidString]
                content.categoryIdentifier = Category.dailyNudge.rawValue

                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: fireDate
                )

                requests.append(
                    UNNotificationRequest(
                        identifier: "\(Self.prefix)daily.\(Int(fireDate.timeIntervalSince1970))",
                        content: content,
                        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    )
                )
            }
        }

        return requests
    }
}
