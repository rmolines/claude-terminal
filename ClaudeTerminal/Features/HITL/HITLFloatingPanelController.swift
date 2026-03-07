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

        // Rebuild the items list — SwiftUI diffs ForEach by sessionID, so only changed items re-render.
        panelState.pendingItems = pendingSessions.map { session in
            let description = session.currentActivity ?? "Agent at \(session.cwd) awaiting approval"
            let risk = RiskSurfaceComputer.compute(toolName: session.pendingToolName, detail: session.currentActivity)
            let suggestions = buildSuggestions(for: session)
            return HITLItem(
                sessionID: session.sessionID,
                description: description,
                toolName: session.pendingToolName,
                riskLevel: risk,
                suggestions: suggestions,
                onApprove: { Task { await SessionManager.shared.approveHITL(sessionID: session.sessionID) } },
                onReject: { reason in Task { await SessionManager.shared.rejectHITL(sessionID: session.sessionID, reason: reason) } },
                onShowInTerminal: { Task { await SessionManager.shared.showInTerminalHITL(sessionID: session.sessionID) } }
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
            // Only suppress the panel from appearing if the Sessions tab already shows inline HITL.
            // Once the panel is visible, keep it visible — hiding it mid-interaction is disruptive.
            if !panel.isVisible {
                let hasInlineHITL = WorkSessionService.shared.workSessions.contains { $0.urgency == .hitlPending }
                if !hasInlineHITL {
                    panel.center()
                    panel.makeKeyAndOrderFront(nil)
                }
            }
        }
    }

    // MARK: - Suggestion builder

    /// Maps Claude Code's `permission_suggestions` IDs to `PermissionSuggestion` values.
    /// Unknown IDs fall back to "Allow" (allow-once). Empty input → empty output (caller uses fallback buttons).
    private func buildSuggestions(for session: AgentSession) -> [PermissionSuggestion] {
        guard !session.pendingSuggestions.isEmpty else { return [] }
        return session.pendingSuggestions.map { id in
            switch id {
            case "yes-session":
                return PermissionSuggestion(
                    id: id,
                    label: "Allow for session",
                    isDestructive: false,
                    action: { Task { await SessionManager.shared.approveHITL(sessionID: session.sessionID, response: .allowSession) } }
                )
            case "reject":
                return PermissionSuggestion(
                    id: id,
                    label: "Reject",
                    isDestructive: true,
                    action: { Task { await SessionManager.shared.rejectHITL(sessionID: session.sessionID) } }
                )
            default:
                return PermissionSuggestion(
                    id: id,
                    label: "Allow",
                    isDestructive: false,
                    action: { Task { await SessionManager.shared.approveHITL(sessionID: session.sessionID) } }
                )
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
