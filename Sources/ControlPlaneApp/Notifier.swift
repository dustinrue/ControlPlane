import Foundation
import UserNotifications
import ControlPlaneSDK

/// Sends macOS Notification Center alerts on behalf of the app.
///
/// Notifications are owned by the application, not by a plugin.
/// Call `Notifier.send(...)` from anywhere within ControlPlaneApp.
/// `UNUserNotificationCenter` is thread-safe; these calls need no actor isolation.
enum Notifier {

    // MARK: - Core send

    static func send(title: String, subtitle: String? = nil, body: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        if let subtitle { content.subtitle = subtitle }
        if let body, !body.isEmpty { content.body = body }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil   // deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error { log("Notification error: \(error)") }
        }
    }

    // MARK: - Profile lifecycle

    static func profileActivated(_ profile: Profile) {
        send(title: "\(profile.name) is now active")
    }

    static func profileDeactivated(_ profile: Profile) {
        send(title: "\(profile.name) is no longer active")
    }

    // MARK: - Startup test

    /// Fires once at launch to confirm Notification Center delivery is working.
    static func startup() {
        send(
            title: "ControlPlane started",
            body: "Monitoring is active."
        )
    }
}
