import Foundation

/// Value type passed to the agent terminal WindowGroup.
///
/// Codable + Hashable so SwiftUI can serialize it for window restoration.
/// `skillCommand` is optional — missing JSON keys decode as `nil` for backward compatibility.
struct AgentTerminalConfig: Codable, Hashable {
    let sessionID: String    // UUID string — used as window identity and PTY uniqueness key
    let worktreePath: String
    let taskTitle: String
    let skillCommand: String?
}
