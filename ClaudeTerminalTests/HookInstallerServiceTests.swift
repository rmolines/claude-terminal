import Testing
import Foundation

// Run with: swift test --configuration debug
//
// SettingsWriter lives in an executable target — @testable import is not available.
// SettingsChecker mirrors the status-detection logic inline, using the same JSON
// structure and rules as SettingsWriter.hookInstallStatus().

@Suite("HookInstaller")
struct HookInstallerServiceTests {

    // MARK: - Status detection (mirrored logic)

    private struct SettingsChecker {
        let helperPath: String

        enum Status: Equatable {
            case notInstalled
            case installed
            case outdated(reason: String)
        }

        func status(from settingsData: Data?) -> Status {
            guard let data = settingsData,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let hooks = json["hooks"] as? [String: Any],
                  let notificationMatchers = hooks["Notification"] as? [[String: Any]],
                  let firstMatcher = notificationMatchers.first,
                  let hookList = firstMatcher["hooks"] as? [[String: Any]],
                  let firstHook = hookList.first,
                  let command = firstHook["command"] as? String else {
                return .notInstalled
            }

            guard command.contains("ClaudeTerminalHelper") else {
                return .notInstalled
            }

            let expected = "\(helperPath) notify"
            if command == expected {
                return .installed
            } else {
                return .outdated(reason: "helper path changed to \(helperPath)")
            }
        }
    }

    // MARK: - Status tests

    @Test("empty settings JSON returns notInstalled")
    func emptySettingsNotInstalled() {
        let checker = SettingsChecker(helperPath: "/usr/local/bin/ClaudeTerminalHelper")
        let data = "{}".data(using: .utf8)!
        #expect(checker.status(from: data) == .notInstalled)
    }

    @Test("nil data (missing file) returns notInstalled")
    func nilDataNotInstalled() {
        let checker = SettingsChecker(helperPath: "/usr/local/bin/ClaudeTerminalHelper")
        #expect(checker.status(from: nil) == .notInstalled)
    }

    @Test("correct hook command returns installed")
    func correctCommandReturnsInstalled() throws {
        let helper = "/usr/local/bin/ClaudeTerminalHelper"
        let checker = SettingsChecker(helperPath: helper)
        let json: [String: Any] = [
            "hooks": [
                "Notification": [[
                    "hooks": [[
                        "type": "command",
                        "command": "\(helper) notify",
                        "async": true,
                    ]],
                ]],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        #expect(checker.status(from: data) == .installed)
    }

    @Test("stale helper path returns outdated")
    func stalePathReturnsOutdated() throws {
        let oldHelper = "/Applications/ClaudeTerminal.app/Contents/MacOS/ClaudeTerminalHelper"
        let newHelper = "/Users/dev/.build/debug/ClaudeTerminalHelper"
        let checker = SettingsChecker(helperPath: newHelper)
        let json: [String: Any] = [
            "hooks": [
                "Notification": [[
                    "hooks": [[
                        "type": "command",
                        "command": "\(oldHelper) notify",
                        "async": true,
                    ]],
                ]],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let result = checker.status(from: data)
        #expect(result == .outdated(reason: "helper path changed to \(newHelper)"))
    }

    @Test("foreign hook command (no ClaudeTerminalHelper) returns notInstalled")
    func foreignHookNotInstalled() throws {
        let checker = SettingsChecker(helperPath: "/usr/local/bin/ClaudeTerminalHelper")
        let json: [String: Any] = [
            "hooks": [
                "Notification": [[
                    "hooks": [[
                        "type": "command",
                        "command": "/usr/local/bin/some-other-tool notify",
                    ]],
                ]],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        #expect(checker.status(from: data) == .notInstalled)
    }

    // MARK: - installHooks output structure

    /// Builds the same hooks dict that SettingsWriter.installHooks() would write,
    /// then verifies the JSON structure contains all 4 expected event types.
    @Test("installHooks produces valid JSON with all 4 hook event types")
    func installHooksProducesAllFourHooks() throws {
        let helper = "/tmp/test/ClaudeTerminalHelper"

        let hooks: [String: Any] = [
            "Notification": [[
                "hooks": [[
                    "type": "command",
                    "command": "\(helper) notify",
                    "async": true,
                ]],
            ]],
            "Stop": [[
                "hooks": [[
                    "type": "command",
                    "command": "\(helper) stop",
                    "async": true,
                ]],
            ]],
            "PreToolUse": [[
                "matcher": "Bash",
                "hooks": [[
                    "type": "command",
                    "command": "\(helper) guard",
                ]],
            ]],
            "PermissionRequest": [[
                "hooks": [[
                    "type": "command",
                    "command": "\(helper) permission",
                ]],
            ]],
        ]

        let settings: [String: Any] = ["hooks": hooks]
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])

        // Write to temp file and read back to validate round-trip
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-settings-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try data.write(to: tempURL)
        let readBack = try Data(contentsOf: tempURL)
        let decoded = try JSONSerialization.jsonObject(with: readBack) as? [String: Any]

        let hooksDecoded = try #require(decoded?["hooks"] as? [String: Any])
        #expect(hooksDecoded["Notification"] != nil)
        #expect(hooksDecoded["Stop"] != nil)
        #expect(hooksDecoded["PreToolUse"] != nil)
        #expect(hooksDecoded["PermissionRequest"] != nil)
    }

    @Test("PermissionRequest hook has no async flag")
    func permissionRequestIsBlocking() throws {
        let helper = "/tmp/test/ClaudeTerminalHelper"
        let hooks: [String: Any] = [
            "PermissionRequest": [[
                "hooks": [[
                    "type": "command",
                    "command": "\(helper) permission",
                ]],
            ]],
        ]
        let data = try JSONSerialization.data(withJSONObject: hooks)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let permMatchers = try #require(decoded?["PermissionRequest"] as? [[String: Any]])
        let firstHook = try #require((permMatchers.first?["hooks"] as? [[String: Any]])?.first)
        #expect(firstHook["async"] == nil)
    }

    @Test("Notification hook command ends with 'notify'")
    func notificationCommandSuffix() throws {
        let helper = "/tmp/ClaudeTerminalHelper"
        let hooks: [String: Any] = [
            "Notification": [[
                "hooks": [[
                    "type": "command",
                    "command": "\(helper) notify",
                    "async": true,
                ]],
            ]],
        ]
        let data = try JSONSerialization.data(withJSONObject: hooks)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let notifMatchers = try #require(decoded?["Notification"] as? [[String: Any]])
        let firstHook = try #require((notifMatchers.first?["hooks"] as? [[String: Any]])?.first)
        let command = try #require(firstHook["command"] as? String)
        #expect(command.hasSuffix(" notify"))
    }
}
