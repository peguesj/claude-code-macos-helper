import Foundation
import UserNotifications

enum NotificationDispatcher {
    static func post(_ alert: Forecaster.Alert) {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = .default

        let req = UNNotificationRequest(
            identifier: alert.id.uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req) { error in
            if let error { Log.warn("notification error: \(error.localizedDescription)") }
        }
    }
}
