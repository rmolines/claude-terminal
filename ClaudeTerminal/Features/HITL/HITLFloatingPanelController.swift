import AppKit
import SwiftUI

/// Manages a floating NSPanel that appears above all windows — including non-ClaudeTerminal apps —
/// whenever any agent session requires HITL approval.
///
/// The panel is created once and reused. It hosts HITLQueueView via NSHostingView and observes
/// SessionStore for all awaitingInput sessions using the same withObservationTracking pattern as AppDelegate.
@MainActor
final class HITLFloatingPanelController {

    // MARK: - Private state

    private lazy var panel: NSPanel = makePanel()
    private var hostingView: NSHostingView<HITLQueueView>?
    /// Shared state read by HITLQueueView. Mutating this lets SwiftUI diff internally
    /// without triggering NSHostingView.rootView = which causes constraint invalidation
    /// during AppKit layout cycles (crash in macOS 26: _postWindowNeedsUpdateConstraints).
    private var panelState = HITLPanelState()

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
        let pendingSessions = SessionStore.shared.sessions.values
            .filter { $0.status == .awaitingInput }
            .sorted { $0.lastEventAt < $1.lastEventAt }

        // Suppress floating panel when the Sessions tab has inline HITL buttons visible.
        // WorkSessionService.workSessions is non-empty only when a project is open and
        // the service has a root directory — i.e. the Sessions tab has been shown.
        let hasInlineHITL = WorkSessionService.shared.workSessions.contains { $0.urgency == .hitlPending }
        if hasInlineHITL {
            panelState.pendingItems = []
            panel.orderOut(nil)
            return
        }

        // Rebuild the items list — SwiftUI diffs ForEach by sessionID, so only changed items re-render.
        panelState.pendingItems = pendingSessions.map { session in
            let description = session.currentActivity ?? "Agent at \(session.cwd) awaiting approval"
            let risk = RiskSurfaceComputer.compute(toolName: session.pendingToolName, detail: session.currentActivity)
            return HITLItem(
                sessionID: session.sessionID,
                description: description,
                toolName: session.pendingToolName,
                riskLevel: risk,
                onApprove: { Task { await SessionManager.shared.approveHITL(sessionID: session.sessionID) } },
                onReject: { Task { await SessionManager.shared.rejectHITL(sessionID: session.sessionID) } }
            )
        }

        if panelState.pendingItems.isEmpty {
            panel.orderOut(nil)
        } else {
            if hostingView == nil {
                let hosting = NSHostingView(rootView: HITLQueueView(state: panelState))
                panel.contentView = hosting
                hostingView = hosting
            }
            if !panel.isVisible {
                panel.center()
                panel.makeKeyAndOrderFront(nil)
            }
        }
    }

    // MARK: - Panel factory

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 360),
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
