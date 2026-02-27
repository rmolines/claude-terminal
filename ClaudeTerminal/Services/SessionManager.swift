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

    func handleEvent(_ event: AgentEvent) {
        switch event.type {
        case .notification, .bashToolUse, .subAgentStarted:
            updateOrCreate(sessionID: event.sessionID, cwd: event.cwd)

        case .permissionRequest:
            updateOrCreate(sessionID: event.sessionID, cwd: event.cwd, status: .awaitingInput)

        case .stopped:
            sessions[event.sessionID]?.status = .completed

        case .heartbeat:
            sessions[event.sessionID]?.lastHeartbeat = Date()
        }
    }

    func approveHITL(sessionID: String) {
        guard sessions[sessionID]?.status == .awaitingInput else { return }
        sessions[sessionID]?.status = .running
        // TODO: signal approval to the hook via socket response
    }

    func rejectHITL(sessionID: String) {
        guard sessions[sessionID]?.status == .awaitingInput else { return }
        sessions[sessionID]?.status = .blocked
        // TODO: signal rejection to the hook via socket response
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
}
