import Foundation

// MARK: - Hook event types received from Claude Code via stdin

/// Token usage reported by Claude Code in the Stop hook.
public struct TokenUsage: Codable, Sendable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheReadTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheReadTokens = "cache_read_input_tokens"
    }
}

/// Raw JSON payload received by ClaudeTerminalHelper from Claude Code hooks.
public struct HookPayload: Codable, Sendable {
    public let sessionID: String
    public let transcriptPath: String?
    public let cwd: String
    public let hookEventName: String
    public let toolName: String?
    public let toolInput: [String: String]?
    public let usage: TokenUsage?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case transcriptPath = "transcript_path"
        case cwd
        case hookEventName = "hook_event_name"
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case usage
    }
}

// MARK: - Typed events forwarded from helper to app

/// A typed agent event sent from ClaudeTerminalHelper to the main app via socket.
public struct AgentEvent: Codable, Sendable {
    public let sessionID: String
    public let type: AgentEventType
    public let cwd: String
    public let timestamp: Date
    public let detail: String?          // truncated bash cmd, permission desc, etc.
    public let tokenUsage: TokenUsage?

    public init(sessionID: String, type: AgentEventType, cwd: String, detail: String? = nil, tokenUsage: TokenUsage? = nil) {
        self.sessionID = sessionID
        self.type = type
        self.cwd = cwd
        self.timestamp = Date()
        self.detail = detail
        self.tokenUsage = tokenUsage
    }
}

// MARK: - Agent status

public enum AgentStatus: String, Codable, Sendable {
    case running
    case awaitingInput = "awaiting_input"
    case completed
    case blocked
}
