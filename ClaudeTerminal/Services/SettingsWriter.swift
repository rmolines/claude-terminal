import Foundation

/// Writes Claude Code hook configuration to ~/.claude/settings.json atomically.
///
/// Security requirements:
/// - Atomic write (temp file + replaceItem) to prevent TOCTOU race conditions.
/// - Never store secrets in settings.json — only hook command paths.
/// - Validate existing JSON schema before modifying.
actor SettingsWriter {
    static let shared = SettingsWriter()

    private let settingsURL: URL = {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".claude")
            .appendingPathComponent("settings.json")
    }()

    /// Resolves the helper binary path at runtime.
    /// Works for dev builds (.build/debug/ClaudeTerminalHelper) and
    /// release .app bundles (Contents/MacOS/ClaudeTerminalHelper).
    private var helperPath: String {
        let execURL = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        return execURL.deletingLastPathComponent()
            .appendingPathComponent("ClaudeTerminalHelper").path
    }

    private init() {}

    /// Returns the current install status of ClaudeTerminal hooks in settings.json.
    func hookInstallStatus() throws -> HookInstallStatus {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            return .notInstalled
        }
        let settings = try readSettings()
        guard let hooks = settings["hooks"] as? [String: Any],
              let notificationMatchers = hooks["Notification"] as? [[String: Any]],
              let firstMatcher = notificationMatchers.first,
              let hookList = firstMatcher["hooks"] as? [[String: Any]],
              let firstHook = hookList.first,
              let command = firstHook["command"] as? String else {
            return .notInstalled
        }

        // If the command doesn't contain "ClaudeTerminalHelper", it's a foreign hook — don't touch it.
        guard command.contains("ClaudeTerminalHelper") else {
            return .notInstalled
        }

        let expectedCommand = "\(helperPath) notify"
        if command == expectedCommand {
            return .installed
        } else {
            return .outdated(reason: "helper path changed to \(helperPath)")
        }
    }

    /// Installs hook configuration in ~/.claude/settings.json.
    /// Merges with existing settings — does not overwrite other keys.
    func installHooks() throws {
        var settings = try readSettings()

        let hooks: [String: Any] = [
            "Notification": [[
                "hooks": [[
                    "type": "command",
                    "command": "\(helperPath) notify",
                    "async": true,
                ]],
            ]],
            "Stop": [[
                "hooks": [[
                    "type": "command",
                    "command": "\(helperPath) stop",
                    "async": true,
                ]],
            ]],
            "PreToolUse": [[
                "matcher": "Bash",
                "hooks": [[
                    "type": "command",
                    "command": "\(helperPath) guard",
                ]],
            ]],
            "PermissionRequest": [[
                "hooks": [[
                    "type": "command",
                    "command": "\(helperPath) permission",
                ]],
            ]],
        ]

        settings["hooks"] = hooks
        try writeSettings(settings)
    }

    func removeHooks() throws {
        var settings = try readSettings()
        settings.removeValue(forKey: "hooks")
        try writeSettings(settings)
    }

    // MARK: - Private

    private func readSettings() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return [:] }
        let data = try Data(contentsOf: settingsURL)
        let json = try JSONSerialization.jsonObject(with: data)
        guard let dict = json as? [String: Any] else {
            throw SettingsError.invalidFormat
        }
        return dict
    }

    private func writeSettings(_ settings: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])

        // Atomic write: temp file + replaceItem (avoids TOCTOU)
        let tempURL = settingsURL.deletingLastPathComponent()
            .appendingPathComponent("settings.json.tmp.\(UUID().uuidString)")

        try data.write(to: tempURL, options: .atomic)
        _ = try FileManager.default.replaceItemAt(settingsURL, withItemAt: tempURL)
    }

    enum SettingsError: Error {
        case invalidFormat
    }
}

// MARK: - HookInstallStatus

public enum HookInstallStatus: Equatable {
    case notInstalled
    case installed
    case outdated(reason: String)
}
