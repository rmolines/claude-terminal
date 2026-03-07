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
                sessions[event.sessionID]?.pendingToolName = event.toolName
                sessions[event.sessionID]?.pendingSuggestions = event.permissionSuggestions ?? []
                await NotificationService.shared.requestHITLApproval(
                    sessionID: event.sessionID,
                    description: "Agent at \(event.cwd) awaiting approval"
                )
            } else {
                // External session (e.g. iTerm) — auto-approve so Claude Code isn't blocked.
                // The user handles permissions inline in their terminal.
                updateOrCreate(sessionID: event.sessionID, cwd: event.cwd)
                await HookIPCServer.shared.respondHITL(sessionID: event.sessionID, response: .allowOnce)
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

    /// Approves a HITL request with the given HookResponse (controls permission level and PTY byte).
    func approveHITL(sessionID: String, response: HookResponse = .allowOnce) async {
        guard sessions[sessionID]?.status == .awaitingInput else { return }
        let cwd = sessions[sessionID]?.cwd
        sessions[sessionID]?.status = .running
        if let session = sessions[sessionID] {
            Task { @MainActor in SessionStore.shared.update(session) }
        }
        await HookIPCServer.shared.respondHITL(sessionID: sessionID, response: response)
        if let cwd, let ptyKey = response.ptyKey {
            Task { @MainActor in TerminalRegistry.shared.sendInput([ptyKey], forCwd: cwd) }
        }
    }

    func rejectHITL(sessionID: String) async {
        await rejectHITL(sessionID: sessionID, reason: "")
    }

    /// Rejects a HITL request and optionally injects an instruction into the PTY.
    /// `reason` is injected as text input to the agent 1.5s after the ESC dismiss,
    /// giving Claude Code time to process the denial and return to the prompt.
    func rejectHITL(sessionID: String, reason: String) async {
        guard sessions[sessionID]?.status == .awaitingInput else { return }
        let cwd = sessions[sessionID]?.cwd
        sessions[sessionID]?.status = .blocked
        if let session = sessions[sessionID] {
            Task { @MainActor in SessionStore.shared.update(session) }
        }
        await HookIPCServer.shared.respondHITL(sessionID: sessionID, response: .deny)
        if let cwd {
            Task { @MainActor in TerminalRegistry.shared.sendInput([0x1b], forCwd: cwd) }
            if !reason.isEmpty {
                let bytes = Array(reason.utf8) + [0x0a]
                Task { @MainActor in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        TerminalRegistry.shared.sendInput(bytes, forCwd: cwd)
                    }
                }
            }
        }
    }

    /// Defers the HITL decision to Claude Code's interactive TUI dialog in the terminal.
    func showInTerminalHITL(sessionID: String) async {
        guard sessions[sessionID]?.status == .awaitingInput else { return }
        sessions[sessionID]?.status = .running
        if let session = sessions[sessionID] {
            Task { @MainActor in SessionStore.shared.update(session) }
        }
        await HookIPCServer.shared.respondHITL(sessionID: sessionID, response: .ask)
        // ptyKey is nil for .ask — we deliberately leave the TUI dialog open for the user.
    }

    // MARK: - Private

    private func updateOrCreate(
        sessionID: String,
        cwd: String,
        status: AgentStatus = .running
    ) {
        let isNew = sessions[sessionID] == nil
        if isNew {
            sessions[sessionID] = AgentSession(sessionID: sessionID, cwd: cwd)

            // Fetch git branch on a dedicated Thread — never block the actor with waitUntilExit().
            Task {
                if let branch = await Self.fetchBranch(cwd: cwd) {
                    self.sessions[sessionID]?.branch = branch
                    if let session = self.sessions[sessionID] {
                        Task { @MainActor in SessionStore.shared.update(session) }
                    }
                }
            }
        }
        // Never downgrade awaitingInput or blocked via a background event (Notification, bash, etc.).
        // Those events are informational and should not resolve a pending HITL decision.
        let current = sessions[sessionID]?.status
        if current != .awaitingInput && current != .blocked {
            sessions[sessionID]?.status = status
        }
        sessions[sessionID]?.lastEventAt = Date()
    }

    /// Runs `git branch --show-current` in a dedicated Thread so the actor is never blocked.
    nonisolated private static func fetchBranch(cwd: String) async -> String? {
        await withCheckedContinuation { continuation in
            let thread = Thread {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = ["-C", cwd, "branch", "--show-current"]
                let outPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = Pipe()
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let raw = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: raw.flatMap { $0.isEmpty ? nil : $0 })
                } catch {
                    continuation.resume(returning: nil)
                }
            }
            thread.start()
        }
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
    /// Git branch name at the session's cwd, populated async after session creation.
    var branch: String?
    /// Tool name from the most recent permissionRequest event (e.g. "Bash", "Write").
    var pendingToolName: String?
    /// Permission suggestion IDs from the most recent permissionRequest event (e.g. ["yes-session", "reject"]).
    var pendingSuggestions: [String] = []
    /// True for sessions registered by the app before any hook fires (e.g. the main Terminal tab).
    /// Evicted automatically when a real hook arrives for the same cwd.
    var isSynthetic: Bool = false
}
