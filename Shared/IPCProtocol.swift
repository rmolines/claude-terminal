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
    /// The user prompt text (only present in UserPromptSubmit hook).
    public let prompt: String?
    /// Permission suggestion IDs sent by Claude Code in PermissionRequest hooks.
    /// Examples: "yes-session", "reject". Nil if Claude Code version doesn't send this field.
    public let permissionSuggestions: [String]?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case transcriptPath = "transcript_path"
        case cwd
        case hookEventName = "hook_event_name"
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case usage
        case prompt
        case permissionSuggestions = "permission_suggestions"
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
    /// True when the Claude Code session was spawned by Claude Terminal (CLAUDE_TERMINAL_MANAGED=1 in PTY env).
    /// False for sessions started externally (e.g. iTerm). Nil from older helper versions = treated as external.
    public let isManagedByApp: Bool?
    /// Tool name forwarded from the Claude Code hook payload (e.g. "Bash", "Write", "Edit").
    /// Non-nil only for permissionRequest and bashToolUse events.
    public let toolName: String?
    /// Permission suggestion IDs forwarded from the PermissionRequest hook payload.
    /// Nil for other event types or if Claude Code version doesn't send this field.
    public let permissionSuggestions: [String]?

    public init(sessionID: String, type: AgentEventType, cwd: String, detail: String? = nil, tokenUsage: TokenUsage? = nil, isManagedByApp: Bool? = nil, toolName: String? = nil, permissionSuggestions: [String]? = nil) {
        self.sessionID = sessionID
        self.type = type
        self.cwd = cwd
        self.timestamp = Date()
        self.detail = detail
        self.tokenUsage = tokenUsage
        self.isManagedByApp = isManagedByApp
        self.toolName = toolName
        self.permissionSuggestions = permissionSuggestions
    }
}

// MARK: - Hook response sent from app back to helper

/// Response sent from the main app to ClaudeTerminalHelper via socket.
/// Helper translates this into stdout JSON + exit code for Claude Code.
public struct HookResponse: Codable, Sendable {
    /// "allow" = approve (exit 0), "deny" = block (exit 2), "ask" = defer to TUI (exit 0 + stdout JSON).
    public let decision: String
    /// PTY byte to inject into the terminal to dismiss Claude Code's interactive TUI dialog.
    /// Nil means no PTY injection (e.g. for "ask" — the TUI stays visible for the user).
    public let ptyKey: UInt8?

    public init(decision: String, ptyKey: UInt8? = nil) {
        self.decision = decision
        self.ptyKey = ptyKey
    }

    public static let allowOnce  = HookResponse(decision: "allow", ptyKey: 0x31)
    public static let allowSession = HookResponse(decision: "allow", ptyKey: 0x32)
    public static let deny       = HookResponse(decision: "deny",  ptyKey: 0x1b)
    public static let ask        = HookResponse(decision: "ask",   ptyKey: nil)
}

// MARK: - Agent status

public enum AgentStatus: String, Codable, Sendable {
    case running
    case awaitingInput = "awaiting_input"
    case completed
    case blocked
}
