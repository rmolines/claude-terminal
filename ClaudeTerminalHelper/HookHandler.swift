import Foundation
import Shared

/// Reads the hook payload from stdin, validates it, and forwards to the main app.
///
/// Security requirements (P0):
/// - Never pass raw hook args to shell.
/// - Always validate that sessionID is a valid UUID before processing.
/// - Never log tool_input content (may contain sensitive data).
final class HookHandler: @unchecked Sendable {
    private let client: IPCClient

    init() {
        client = IPCClient()
    }

    func run() -> Int32 {
        // Read JSON payload from stdin (Claude Code sends hook data via stdin)
        guard let data = readStdin() else {
            fputs("claude-terminal-helper: failed to read stdin\n", stderr)
            return 1
        }

        guard let payload = parsePayload(data) else {
            fputs("claude-terminal-helper: invalid hook payload\n", stderr)
            return 1
        }

        // Validate sessionID is a UUID (allowlist check)
        guard UUID(uuidString: payload.sessionID) != nil else {
            fputs("claude-terminal-helper: invalid sessionID format\n", stderr)
            return 1
        }

        let eventType = mapEventType(hookName: payload.hookEventName, toolName: payload.toolName)

        // UserPromptSubmit: only forward slash commands to avoid noise
        if eventType == .userPromptSubmit {
            guard let prompt = payload.prompt, prompt.hasPrefix("/") else {
                return 0
            }
        }

        let detail: String?
        if eventType == .bashToolUse {
            detail = payload.toolInput?["command"].map { String($0.prefix(80)) }
        } else if eventType == .permissionRequest {
            // PermissionRequest: prefer "command" (Bash), then file path keys for file tools, then description/tool name.
            // Split into two expressions to avoid Swift type-checker timeout on long ?? chains.
            let pathOrCommand: String? = payload.toolInput?["command"]
                ?? payload.toolInput?["file_path"]
                ?? payload.toolInput?["path"]
            let rawDetail: String? = pathOrCommand
                ?? payload.toolInput?["pattern"]
                ?? payload.toolInput?["description"]
                ?? payload.toolName
            detail = rawDetail.map { String($0.prefix(120)) }
        } else if eventType == .notification {
            detail = payload.toolInput?["message"].map { String($0.prefix(200)) }
        } else if eventType == .userPromptSubmit {
            detail = payload.prompt.map { String($0.prefix(100)) }
        } else {
            detail = nil
        }
        let isManagedByApp = ProcessInfo.processInfo.environment["CLAUDE_TERMINAL_MANAGED"] == "1"
        let forwardToolName = (eventType == .permissionRequest || eventType == .bashToolUse) ? payload.toolName : nil
        let suggestions = eventType == .permissionRequest ? payload.permissionSuggestions : nil
        let event = AgentEvent(
            sessionID: payload.sessionID,
            type: eventType,
            cwd: payload.cwd,
            detail: detail,
            tokenUsage: payload.usage,
            isManagedByApp: isManagedByApp,
            toolName: forwardToolName,
            permissionSuggestions: suggestions
        )

        if eventType == .permissionRequest {
            // Block until app responds with a HookResponse.
            // decision "allow" → exit 0; "deny" → exit 2; "ask" → stdout JSON + exit 0.
            let response = client.sendAndAwaitResponse(event: event)
            switch response.decision {
            case "ask":
                print("{\"permissionDecision\":\"ask\"}", terminator: "")
                return 0
            case "deny":
                return 2
            default: // "allow"
                return 0
            }
        } else {
            client.send(event: event)
            return 0
        }
    }

    // MARK: - Private

    private func readStdin() -> Data? {
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
        defer { buffer.deallocate() }

        while true {
            let count = read(STDIN_FILENO, buffer, 4096)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data.isEmpty ? nil : data
    }

    private func parsePayload(_ data: Data) -> HookPayload? {
        let decoder = JSONDecoder()
        return try? decoder.decode(HookPayload.self, from: data)
    }

    private func mapEventType(hookName: String, toolName: String?) -> AgentEventType {
        switch hookName {
        case "Notification":
            return .notification
        case "Stop":
            return .stopped
        case "PreToolUse" where toolName == "Bash":
            return .bashToolUse
        case "PermissionRequest":
            return .permissionRequest
        case "UserPromptSubmit":
            return .userPromptSubmit
        default:
            return .notification
        }
    }
}
