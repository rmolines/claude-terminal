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
        let detail: String?
        if eventType == .bashToolUse {
            detail = payload.toolInput?["command"].map { String($0.prefix(80)) }
        } else if eventType == .permissionRequest {
            detail = payload.toolInput?["description"].map { String($0.prefix(80)) }
        } else {
            detail = nil
        }
        let event = AgentEvent(
            sessionID: payload.sessionID,
            type: eventType,
            cwd: payload.cwd,
            detail: detail
        )

        if eventType == .permissionRequest {
            // Block until app responds — exit code controls Claude Code's action:
            //   0 = allow the operation
            //   2 = block the operation (Claude Code spec for permission hooks)
            let approved = client.sendAndAwaitResponse(event: event)
            return approved == 1 ? 0 : 2
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
        default:
            return .notification
        }
    }
}
