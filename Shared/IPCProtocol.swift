import Foundation

// MARK: - Hook event types received from Claude Code via stdin

/// Raw JSON payload received by ClaudeTerminalHelper from Claude Code hooks.
public struct HookPayload: Codable, Sendable {
    public let sessionID: String
    public let transcriptPath: String?
    public let cwd: String
    public let hookEventName: String
    public let toolName: String?
    public let toolInput: [String: String]?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case transcriptPath = "transcript_path"
        case cwd
        case hookEventName = "hook_event_name"
        case toolName = "tool_name"
        case toolInput = "tool_input"
    }
}

// MARK: - Typed events forwarded from helper to app

/// A typed agent event sent from ClaudeTerminalHelper to the main app via socket.
public struct AgentEvent: Codable, Sendable {
    public let sessionID: String
    public let type: AgentEventType
    public let cwd: String
    public let timestamp: Date

    public init(sessionID: String, type: AgentEventType, cwd: String) {
        self.sessionID = sessionID
        self.type = type
        self.cwd = cwd
        self.timestamp = Date()
    }
}

// MARK: - Agent status

public enum AgentStatus: String, Codable, Sendable {
    case running
    case awaitingInput = "awaiting_input"
    case completed
    case blocked
}
