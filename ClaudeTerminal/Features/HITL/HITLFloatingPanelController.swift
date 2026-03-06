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
    /// Shared state read by HITLPanelView. Mutating this lets SwiftUI diff internally
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
        let pending = SessionStore.shared.sessions.values.first { $0.status == .awaitingInput }
        if let session = pending {
            show(session: session)
        } else {
            panel.orderOut(nil)
        }
    }

    // MARK: - Show / dismiss

    private func show(session: AgentSession) {
        let description = session.currentActivity ?? "Agent at \(session.cwd) awaiting approval"

        // Update shared state — SwiftUI diffs internally without touching rootView.
        // Never set hosting.rootView = while the panel is visible: that invalidates
        // NSHostingView constraints during AppKit layout cycles (macOS 26 crash).
        panelState.sessionID = session.sessionID
        panelState.description = description
        panelState.onApprove = { Task { await SessionManager.shared.approveHITL(sessionID: session.sessionID) } }
        panelState.onReject = { Task { await SessionManager.shared.rejectHITL(sessionID: session.sessionID) } }

        if hostingView == nil {
            let hosting = NSHostingView(rootView: HITLPanelView(state: panelState))
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
