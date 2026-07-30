import EventKit
import Foundation

/// A stretch of unclaimed time.
struct TimeGap: Equatable, Sendable, Identifiable {
    var start: Date
    var end: Date

    var id: Date { start }
    var minutes: Int { Int(end.timeIntervalSince(start) / 60) }
}

/// Finds gaps in a day. The maths is separated from EventKit so it can be tested without
/// a calendar, a device, or a permission prompt.
enum FreeTimeFinder {

    /// Merges overlapping busy intervals and returns what's left inside `window`.
    static func gaps(
        busy: [DateInterval],
        within window: DateInterval,
        minimumMinutes: Int
    ) -> [TimeGap] {
        let minimum = TimeInterval(minimumMinutes * 60)

        // Clip to the window first, so an all-day event doesn't swallow everything.
        let clipped = busy
            .compactMap { $0.intersection(with: window) }
            .filter { $0.duration > 0 }
            .sorted { $0.start < $1.start }

        // Merge overlaps — back-to-back meetings are one busy block, not two, and the gap
        // between them is not free time.
        var merged: [DateInterval] = []
        for interval in clipped {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1] = DateInterval(
                    start: last.start,
                    end: max(last.end, interval.end)
                )
            } else {
                merged.append(interval)
            }
        }

        var result: [TimeGap] = []
        var cursor = window.start

        for interval in merged {
            if interval.start.timeIntervalSince(cursor) >= minimum {
                result.append(TimeGap(start: cursor, end: interval.start))
            }
            cursor = max(cursor, interval.end)
        }

        if window.end.timeIntervalSince(cursor) >= minimum {
            result.append(TimeGap(start: cursor, end: window.end))
        }

        return result
    }

    /// The waking part of a given day, as a window to search within.
    static func wakingWindow(
        on day: Date,
        startHour: Int,
        endHour: Int,
        calendar: Calendar = .current
    ) -> DateInterval? {
        guard
            let start = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: day),
            let end = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: day),
            end > start
        else { return nil }
        return DateInterval(start: start, end: end)
    }
}

/// Reads busy times from the user's calendars.
///
/// Only *when* they are busy is ever read — never what the events are. That is worth being
/// exact about, because it is the whole justification for asking for calendar access.
@MainActor
final class CalendarBusyReader {

    private let store = EKEventStore()

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    var isAuthorized: Bool {
        authorizationStatus == .fullAccess
    }

    /// Requests access. Only ever called from the free-time setting being switched on, so
    /// the prompt arrives with obvious context rather than at launch.
    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    func busyIntervals(in window: DateInterval) -> [DateInterval] {
        guard isAuthorized else { return [] }

        let predicate = store.predicateForEvents(
            withStart: window.start,
            end: window.end,
            calendars: nil
        )

        return store.events(matching: predicate).compactMap { event in
            // All-day events say nothing about availability — plenty of people have a
            // birthday in their calendar and a completely free afternoon.
            guard !event.isAllDay, event.status != .canceled else { return nil }
            guard event.availability != .free else { return nil }
            guard let start = event.startDate, let end = event.endDate, end > start else { return nil }
            return DateInterval(start: start, end: end)
        }
    }
}
