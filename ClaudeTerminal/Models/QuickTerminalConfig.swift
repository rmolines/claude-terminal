import Foundation

/// Configuration for a quick terminal window (not tied to a task or agent).
///
/// Each call to openWindow creates a new UUID, so opening the same directory
/// twice produces two independent terminal windows.
struct QuickTerminalConfig: Codable, Hashable {
    var id: UUID
    var directoryPath: String
    var displayTitle: String

    init(directoryPath: String) {
        self.id = UUID()
        self.directoryPath = directoryPath
        // Use the last path component as the display title (e.g. "my-repo")
        self.displayTitle = URL(fileURLWithPath: directoryPath).lastPathComponent
    }
}
