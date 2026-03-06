import Foundation
import Shared

/// Central actor that manages all active Claude Code agent sessions.
///
/// All state mutations happen on this actor. UI subscribes via published properties
/// after hopping to @MainActor.
actor SessionManager {
    static let shared = SessionManager()

    // Active sessions keyed by Claude Code session_id
    private(set) var sessions: [String: AgentSession] = [:]

    private init() {}

    // MARK: - Session lifecycle

    func handleEvent(_ event: AgentEvent) async {
        switch event.type {
        case .notification:
            updateOrCreate(sessionID: event.sessionID, cwd: event.cwd)
            if let msg = event.detail, !msg.isEmpty {
                var msgs = sessions[event.sessionID]?.recentMessages ?? []
                msgs.insert(msg, at: 0)
                if msgs.count > 3 { msgs = Array(msgs.prefix(3)) }
                sessions[event.sessionID]?.recentMessages = msgs
            }

        case .bashToolUse:
            updateOrCreate(sessionID: event.sessionID, cwd: event.cwd)
            if let cmd = event.detail {
                sessions[event.sessionID]?.currentActivity = "$ \(cmd)"
                let cwd = event.cwd
                Task { @MainActor in WorkflowUpdateService.shared.applyBashFingerprint(cmd, forProjectAt: cwd) }
            }

        case .subAgentStarted:
            updateOrCreate(sessionID: event.sessionID, cwd: event.cwd)
            sessions[event.sessionID]?.subAgentCount += 1
            sessions[event.sessionID]?.currentActivity = "Sub-agent spawned"

        case .permissionRequest:
            if event.isManagedByApp == true {
                updateOrCreate(sessionID: event.sessionID, cwd: event.cwd, status: .awaitingInput)
                sessions[event.sessionID]?.currentActivity = event.detail ?? "Awaiting approval"
                await NotificationService.shared.requestHITLApproval(
                    sessionID: event.sessionID,
                    description: "Agent at \(event.cwd) awaiting approval"
                )
            } else {
                // External session (e.g. iTerm) — auto-approve so Claude Code isn't blocked.
                // The user handles permissions inline in their terminal.
                updateOrCreate(sessionID: event.sessionID, cwd: event.cwd)
                await HookIPCServer.shared.respondHITL(sessionID: event.sessionID, approved: true)
                return
            }

        case .stopped:
            sessions[event.sessionID]?.status = .completed
            sessions[event.sessionID]?.currentActivity = "Completed"

        case .heartbeat:
            sessions[event.sessionID]?.lastHeartbeat = Date()

        case .userPromptSubmit:
            updateOrCreate(sessionID: event.sessionID, cwd: event.cwd)
            if let prompt = event.detail {
                let skillID = String(prompt.components(separatedBy: " ").first ?? prompt)
                sessions[event.sessionID]?.currentActivity = skillID
                let cwd = event.cwd
                Task { @MainActor in WorkflowUpdateService.shared.markActive(skillID: skillID, forProjectAt: cwd) }
            }
        }

        if let usage = event.tokenUsage {
            sessions[event.sessionID]?.totalInputTokens += usage.inputTokens
            sessions[event.sessionID]?.totalOutputTokens += usage.outputTokens
            sessions[event.sessionID]?.totalCacheReadTokens += usage.cacheReadTokens
        }

        // Only push managed sessions to the store — external sessions (iTerm, etc.) stay invisible in the UI.
        if let session = sessions[event.sessionID], event.isManagedByApp == true {
            Task { @MainActor in SessionStore.shared.update(session) }
        }
    }

    func approveHITL(sessionID: String) async {
        guard sessions[sessionID]?.status == .awaitingInput else { return }
        let cwd = sessions[sessionID]?.cwd
        sessions[sessionID]?.status = .running
        if let session = sessions[sessionID] {
            Task { @MainActor in SessionStore.shared.update(session) }
        }
        await HookIPCServer.shared.respondHITL(sessionID: sessionID, approved: true)
        // Forward "1" keypress to the PTY to dismiss Claude Code's interactive TUI permission dialog.
        // Claude Code's permission menu is in raw mode — a single "1" keypress confirms "Yes" immediately.
        if let cwd {
            Task { @MainActor in TerminalRegistry.shared.sendInput([0x31], forCwd: cwd) }
        }
    }

    func rejectHITL(sessionID: String) async {
        guard sessions[sessionID]?.status == .awaitingInput else { return }
        let cwd = sessions[sessionID]?.cwd
        sessions[sessionID]?.status = .blocked
        if let session = sessions[sessionID] {
            Task { @MainActor in SessionStore.shared.update(session) }
        }
        await HookIPCServer.shared.respondHITL(sessionID: sessionID, approved: false)
        // Forward Escape to the PTY to cancel Claude Code's interactive TUI permission dialog.
        if let cwd {
            Task { @MainActor in TerminalRegistry.shared.sendInput([0x1b], forCwd: cwd) }
        }
    }

    // MARK: - Private

    private func updateOrCreate(
        sessionID: String,
        cwd: String,
        status: AgentStatus = .running
    ) {
        if sessions[sessionID] == nil {
            sessions[sessionID] = AgentSession(sessionID: sessionID, cwd: cwd)
        }
        sessions[sessionID]?.status = status
        sessions[sessionID]?.lastEventAt = Date()
    }
}

// MARK: - Supporting types

struct AgentSession: Sendable {
    let sessionID: String
    let cwd: String
    var status: AgentStatus = .running
    var lastEventAt: Date = Date()
    var lastHeartbeat: Date = Date()
    let startedAt: Date = Date()
    var currentActivity: String?
    var subAgentCount: Int = 0
    var totalInputTokens: Int = 0
    var totalOutputTokens: Int = 0
    var totalCacheReadTokens: Int = 0
    var recentMessages: [String] = []
    /// True for sessions registered by the app before any hook fires (e.g. the main Terminal tab).
    /// Evicted automatically when a real hook arrives for the same cwd.
    var isSynthetic: Bool = false
}
