import Foundation
import Observation
import UserNotifications

/// Routes a tapped notification back to the idea it was about.
///
/// A resurfacing notification that opens the app to a generic list has wasted the
/// interruption — the whole point is to put *that* idea back in front of you.
@MainActor
@Observable
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {

    /// Set when a notification is tapped; the shell observes it and navigates.
    var pendingIdeaID: UUID?

    /// True when a review-style notification was tapped rather than an idea one.
    var shouldOpenReview = false

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let category = response.notification.request.content.categoryIdentifier

        await MainActor.run {
            if category == NotificationScheduler.Category.weeklyReview.rawValue {
                shouldOpenReview = true
                return
            }
            if let raw = userInfo["ideaID"] as? String, let id = UUID(uuidString: raw) {
                pendingIdeaID = id
            }
        }
    }

    /// Shows the banner even when Remli is open. Suppressing it would leave someone who
    /// happens to be in the app with no idea a nudge just fired.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
