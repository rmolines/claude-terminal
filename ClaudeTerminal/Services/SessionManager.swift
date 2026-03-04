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
            }

        case .subAgentStarted:
            updateOrCreate(sessionID: event.sessionID, cwd: event.cwd)
            sessions[event.sessionID]?.subAgentCount += 1
            sessions[event.sessionID]?.currentActivity = "Sub-agent spawned"

        case .permissionRequest:
            updateOrCreate(sessionID: event.sessionID, cwd: event.cwd, status: .awaitingInput)
            sessions[event.sessionID]?.currentActivity = event.detail ?? "Awaiting approval"
            await NotificationService.shared.requestHITLApproval(
                sessionID: event.sessionID,
                description: "Agent at \(event.cwd) awaiting approval"
            )

        case .stopped:
            sessions[event.sessionID]?.status = .completed
            sessions[event.sessionID]?.currentActivity = "Completed"

        case .heartbeat:
            sessions[event.sessionID]?.lastHeartbeat = Date()
        }

        if let usage = event.tokenUsage {
            sessions[event.sessionID]?.totalInputTokens += usage.inputTokens
            sessions[event.sessionID]?.totalOutputTokens += usage.outputTokens
            sessions[event.sessionID]?.totalCacheReadTokens += usage.cacheReadTokens
        }

        if let session = sessions[event.sessionID] {
            Task { @MainActor in SessionStore.shared.update(session) }
        }
    }

    func approveHITL(sessionID: String) async {
        guard sessions[sessionID]?.status == .awaitingInput else { return }
        sessions[sessionID]?.status = .running
        await HookIPCServer.shared.respondHITL(sessionID: sessionID, approved: true)
    }

    func rejectHITL(sessionID: String) async {
        guard sessions[sessionID]?.status == .awaitingInput else { return }
        sessions[sessionID]?.status = .blocked
        await HookIPCServer.shared.respondHITL(sessionID: sessionID, approved: false)
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
}
