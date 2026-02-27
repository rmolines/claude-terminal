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

    private let helperPath = "/Applications/ClaudeTerminal.app/Contents/MacOS/ClaudeTerminalHelper"

    private init() {}

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
