import AppKit
import SwiftUI

/// Manages a floating NSPanel that appears above all windows — including non-ClaudeTerminal apps —
/// whenever an agent session requires HITL approval.
///
/// The panel is created once and reused. It hosts HITLPanelView via NSHostingView and observes
/// SessionStore for awaitingInput sessions using the same withObservationTracking pattern as AppDelegate.
@MainActor
final class HITLFloatingPanelController {

    // MARK: - Private state

    private lazy var panel: NSPanel = makePanel()
    private var hostingView: NSHostingView<HITLPanelView>?

    // MARK: - Lifecycle

    /// Begin observing SessionStore. Call once from applicationDidFinishLaunching.
    func start() {
        observeSessions()
    }

    // MARK: - Observation

    /// Re-subscribes after each change — canonical pattern for @Observable outside SwiftUI views.
    private func observeSessions() {
        withObservationTracking {
            _ = SessionStore.shared.sessions
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updatePanel()
                self?.observeSessions()
            }
        }
    }

    private func updatePanel() {
        let pending = SessionStore.shared.sessions.values.first { $0.status == .awaitingInput }
        if let session = pending {
            show(session: session)
        } else {
            panel.orderOut(nil)
        }
    }

    // MARK: - Show / dismiss

    private func show(session: AgentSession) {
        let view = HITLPanelView(
            sessionID: session.sessionID,
            description: session.currentActivity ?? "Agent at \(session.cwd) awaiting approval"
        ) {
            Task { await SessionManager.shared.approveHITL(sessionID: session.sessionID) }
        } onReject: {
            Task { await SessionManager.shared.rejectHITL(sessionID: session.sessionID) }
        }

        if let hosting = hostingView {
            hosting.rootView = view
        } else {
            let hosting = NSHostingView(rootView: view)
            hosting.sizingOptions = [.minSize]
            panel.contentView = hosting
            hostingView = hosting
        }

        if !panel.isVisible {
            panel.center()
            panel.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Panel factory

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Claude Terminal"
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        return panel
    }
}
