import Foundation
import SwiftData

/// Frozen V1 schema — snapshot of the model graph before M4 additions.
///
/// Required by SwiftData migration: the old schema must be captured before
/// any model changes. Never edit this file after the V1→V2 migration is live.
///
/// IMPORTANT: inner class names MUST match the Core Data entity names in the
/// existing on-disk store ("ClaudeTask" and "ClaudeAgent"). Using suffix names
/// like "ClaudeTaskV1" generates mismatched entity names, so Core Data cannot
/// find a source model that matches the store and the migration throws.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [ClaudeTask.self, ClaudeAgent.self]
    }

    @Model
    final class ClaudeTask {
        var id: UUID
        var title: String
        var taskType: String
        var status: String
        var createdAt: Date
        var sortOrder: Int

        @Relationship(deleteRule: .cascade, inverse: \ClaudeAgent.task)
        var agents: [ClaudeAgent]?

        init(title: String, taskType: String) {
            self.id = UUID()
            self.title = title
            self.taskType = taskType
            self.status = "running"
            self.createdAt = Date()
            self.sortOrder = 0
        }
    }

    @Model
    final class ClaudeAgent {
        var id: UUID
        var sessionID: String
        var status: String
        var worktreePath: String?
        var branchName: String?
        var baseCommitSHA: String?
        var startedAt: Date
        var completedAt: Date?
        var sortOrder: Int

        var task: ClaudeTask?

        init(sessionID: String) {
            self.id = UUID()
            self.sessionID = sessionID
            self.status = "running"
            self.startedAt = Date()
            self.sortOrder = 0
        }
    }
}
