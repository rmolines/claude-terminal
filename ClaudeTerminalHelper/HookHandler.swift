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

    func run() {
        // Read JSON payload from stdin (Claude Code sends hook data via stdin)
        guard let data = readStdin() else {
            fputs("claude-terminal-helper: failed to read stdin\n", stderr)
            exit(1)
        }

        guard let payload = parsePayload(data) else {
            fputs("claude-terminal-helper: invalid hook payload\n", stderr)
            exit(1)
        }

        // Validate sessionID is a UUID (allowlist check)
        guard UUID(uuidString: payload.sessionID) != nil else {
            fputs("claude-terminal-helper: invalid sessionID format\n", stderr)
            exit(1)
        }

        let eventType = mapEventType(hookName: payload.hookEventName, toolName: payload.toolName)
        let event = AgentEvent(
            sessionID: payload.sessionID,
            type: eventType,
            cwd: payload.cwd
        )

        client.send(event: event)
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
