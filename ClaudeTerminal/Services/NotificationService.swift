import Foundation
import UserNotifications

/// Sends actionable HITL notifications via UNUserNotificationCenter.
///
/// Actions (Approve/Reject) are handled in AppDelegate.userNotificationCenter(_:didReceive:)
/// WITHOUT opening the app (no .foreground option).
actor NotificationService {
    static let shared = NotificationService()

    private init() {}

    /// Posts an HITL approval request notification.
    /// - Parameter sessionID: Used as the notification identifier for callback routing.
    func requestHITLApproval(sessionID: String, description: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Claude Terminal — Approval Required"
        content.body = description
        content.categoryIdentifier = "HITL_REQUEST"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: sessionID,
            content: content,
            trigger: nil  // deliver immediately
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    func notifyAgentCompleted(sessionID: String, title: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Claude Terminal — Task Complete"
        content.body = title
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "completed-\(sessionID)",
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}
