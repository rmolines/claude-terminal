import Foundation

/// Configuration for a quick Claude Code session window (not tied to a task or agent).
///
/// Each call to openWindow creates a new UUID, so opening the same directory
/// twice produces two independent session windows. The sessionID is used as a
/// routing key for the reply box — NotificationCenter matches on `cwd`.
struct QuickAgentConfig: Codable, Hashable {
    var id: UUID
    var sessionID: String
    var directoryPath: String
    var displayTitle: String

    init(directoryPath: String) {
        self.id = UUID()
        self.sessionID = UUID().uuidString
        self.directoryPath = directoryPath
        self.displayTitle = URL(fileURLWithPath: directoryPath).lastPathComponent
    }
}
