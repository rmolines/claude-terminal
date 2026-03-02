import Foundation
import SwiftData

/// A git repository or workspace that groups related tasks.
///
/// Relationship to ClaudeTask uses .nullify so deleting a project
/// keeps the tasks (they move to the "Other" group in the sidebar).
@Model
final class ClaudeProject {
    var id: UUID
    var name: String
    var path: String       // absolute filesystem path, e.g. "/Users/dev/git/my-app"
    var createdAt: Date
    var sortOrder: Int     // SwiftData does not preserve array ordering

    @Relationship(deleteRule: .nullify, inverse: \ClaudeTask.project)
    var tasks: [ClaudeTask]?

    init(name: String, path: String) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.createdAt = Date()
        self.sortOrder = 0
    }
}
