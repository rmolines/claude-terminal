import Foundation

/// Events emitted by Claude Code hooks and forwarded by the helper to the main app.
public enum AgentEventType: String, Codable, Sendable {
    /// Agent emitted a general notification.
    case notification

    /// Agent is awaiting a permission approval (HITL trigger).
    case permissionRequest = "permission_request"

    /// Agent completed its task (Stop hook).
    case stopped

    /// Agent is about to run a Bash command (PreToolUse).
    case bashToolUse = "bash_tool_use"

    /// Agent started a new sub-agent in the background.
    case subAgentStarted = "sub_agent_started"

    /// Heartbeat — helper is still alive.
    case heartbeat
}
