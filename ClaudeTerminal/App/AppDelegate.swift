import AppKit
import Observation
import UserNotifications

/// AppDelegate handles: NSStatusItem (menu bar badge), NSPanel (HITL HUD),
/// UNUserNotificationCenter setup, and lifecycle events.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupNotifications()
        Task { await HookIPCServer.shared.start() }
        observeSessionStore()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false  // Stay alive as menu bar app even when window is closed
    }

    // MARK: - Badge observation

    /// Reactively updates the badge whenever SessionStore.pendingHITLCount changes.
    /// Re-subscribes after each change — the canonical pattern for @Observable outside SwiftUI.
    private func observeSessionStore() {
        withObservationTracking {
            _ = SessionStore.shared.pendingHITLCount
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateBadge(count: SessionStore.shared.pendingHITLCount)
                self?.observeSessionStore()
            }
        }
    }

    // MARK: - Menu bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateBadge(count: 0)
    }

    func updateBadge(count: Int) {
        guard let button = statusItem?.button else { return }
        if count == 0 {
            button.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "Claude Terminal")
        } else {
            button.image = badgedImage(count: count)
        }
    }

    private func badgedImage(count: Int) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let result = NSImage(size: size)
        result.lockFocus()

        NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)?
            .draw(in: NSRect(origin: .zero, size: size))

        let badgeRect = NSRect(x: 10, y: 10, width: 8, height: 8)
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: badgeRect).fill()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 5, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        String(min(count, 9)).draw(in: badgeRect, withAttributes: attrs)

        result.unlockFocus()
        return result
    }

    // MARK: - Notifications

    private func setupNotifications() {
        // UNUserNotificationCenter requires a proper app bundle (CFBundleIdentifier).
        // When running as a bare SPM executable (no .app wrapper), skip notification setup.
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let approveAction = UNNotificationAction(
            identifier: "APPROVE_ACTION",
            title: "Approve",
            options: []  // background — does not open app
        )
        let rejectAction = UNNotificationAction(
            identifier: "REJECT_ACTION",
            title: "Reject",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: "HITL_REQUEST",
            actions: [approveAction, rejectAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let sessionID = response.notification.request.identifier
        switch response.actionIdentifier {
        case "APPROVE_ACTION":
            Task { await SessionManager.shared.approveHITL(sessionID: sessionID) }
        case "REJECT_ACTION":
            Task { await SessionManager.shared.rejectHITL(sessionID: sessionID) }
        default:
            break
        }
        completionHandler()
    }
}
