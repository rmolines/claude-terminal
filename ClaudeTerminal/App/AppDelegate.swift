import AppKit
import Sparkle
import UserNotifications

/// AppDelegate handles: NSStatusItem (menu bar badge), NSPanel (HITL HUD),
/// UNUserNotificationCenter setup, and lifecycle events.
///
/// Also acts as `SPUUpdaterDelegate` to save terminal snapshots before Sparkle relaunches the app,
/// preserving session context across updates.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, SPUUpdaterDelegate {
    private var statusItem: NSStatusItem?
    var updaterController: SPUStandardUpdaterController!
    private var hitlPanelController: HITLFloatingPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force regular activation policy so the app receives keyboard events properly
        // when running as an SPM binary without a full .app bundle.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Close extra windows restored by macOS state restoration — this is a single-window app.
        // WindowGroup allows macOS to reopen all windows from the previous session; we want only one.
        DispatchQueue.main.async {
            let mainWindows = NSApp.windows.filter { !($0 is NSPanel) }
            mainWindows.dropFirst().forEach { $0.close() }
        }

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )

        setupMenuBar()
        setupNotifications()
        Task { await HookIPCServer.shared.start() }
        hitlPanelController = HITLFloatingPanelController()
        hitlPanelController?.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false  // Stay alive as menu bar app even when window is closed
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Warn if real (non-synthetic) agents are still running
        let running = SessionStore.shared.sessions.values
            .filter { !$0.isSynthetic && $0.status == .running }.count
        if running > 0 {
            let alert = NSAlert()
            alert.messageText = "\(running) agent\(running == 1 ? "" : "s") still running"
            alert.informativeText = "Claude Code sessions are active. Quit anyway?"
            alert.addButton(withTitle: "Quit")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .warning
            if alert.runModal() == .alertSecondButtonReturn {
                return .terminateCancel
            }
        }

        // Save terminal snapshots synchronously (all @MainActor, < 100ms)
        let snapshots = TerminalRegistry.shared.captureAll()
        for snapshot in snapshots {
            try? TerminalSnapshotStore.shared.save(
                projectID: snapshot.projectID,
                path: snapshot.path,
                content: snapshot.data
            )
        }

        return .terminateNow
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

    // MARK: - SPUUpdaterDelegate

    /// Called by Sparkle right before it relaunches the app to apply an update.
    /// Saves all terminal snapshots so they can be restored after the update.
    nonisolated func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        Task { @MainActor in
            let snapshots = TerminalRegistry.shared.captureAll()
            for snapshot in snapshots {
                try? TerminalSnapshotStore.shared.save(
                    projectID: snapshot.projectID,
                    path: snapshot.path,
                    content: snapshot.data
                )
            }
        }
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
