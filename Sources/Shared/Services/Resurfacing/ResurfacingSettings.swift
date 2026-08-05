import Foundation
import Observation

/// A time of day, to the minute.
struct DayTime: Codable, Equatable, Hashable, Identifiable, Sendable, Comparable {
    var hour: Int
    var minute: Int

    var id: Int { hour * 60 + minute }

    static func < (lhs: DayTime, rhs: DayTime) -> Bool { lhs.id < rhs.id }

    var displayString: String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}

/// How and when Remli brings ideas back.
///
/// Defaults are deliberately quiet: one nudge a day and a weekly review, with calendar
/// reading off. An app that starts by asking for calendar access and sending six
/// notifications a day gets its notifications disabled on day one, after which none of
/// this works at all.
struct ResurfacingSettings: Codable, Equatable, Sendable {

    var dailyNudgesEnabled: Bool = true

    /// A set of times, not one. Chris asked to be able to pick several points in a day.
    var dailyTimes: [DayTime] = [DayTime(hour: 9, minute: 0)]

    var weeklyReviewEnabled: Bool = true
    /// 1 = Sunday, matching `Calendar`'s weekday numbering.
    var weeklyReviewWeekday: Int = 1
    var weeklyReviewHour: Int = 18

    var freeTimeEnabled: Bool = false
    /// Below this, a gap isn't long enough to start anything worth starting.
    var freeTimeMinimumMinutes: Int = 45

    /// Nothing is ever scheduled outside these hours, whatever else is configured.
    var dayStartHour: Int = 8
    var dayEndHour: Int = 22

    var hasAnythingEnabled: Bool {
        (dailyNudgesEnabled && !dailyTimes.isEmpty) || weeklyReviewEnabled || freeTimeEnabled
    }
}

@MainActor
@Observable
final class ResurfacingSettingsStore {

    private static let key = "remli.resurfacing.settings"

    var settings: ResurfacingSettings {
        didSet {
            guard settings != oldValue else { return }
            persist()
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(ResurfacingSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = ResurfacingSettings()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }

    func addDailyTime(_ time: DayTime) {
        guard !settings.dailyTimes.contains(time) else { return }
        settings.dailyTimes = (settings.dailyTimes + [time]).sorted()
    }

    func removeDailyTime(_ time: DayTime) {
        settings.dailyTimes.removeAll { $0 == time }
    }
}
