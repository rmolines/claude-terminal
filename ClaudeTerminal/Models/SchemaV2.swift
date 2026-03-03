import Foundation
@preconcurrency import SwiftData

/// V2 schema — adds ClaudeProject and priority to ClaudeTask.
///
/// Lightweight migration contract (what SwiftData sets on migrated V1 rows):
/// - `ClaudeTask.priority` → `""` (empty string, since the field is non-optional)
///   `prioritySortKey` and `priorityDisplay` treat `""` as "medium" via their `default` cases.
/// - `ClaudeTask.project` → `nil` (tasks appear in "Other" sidebar section)
/// - `ClaudeProject` rows → none (new entity, starts empty)
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [ClaudeTask.self, ClaudeAgent.self, ClaudeProject.self]
    }
}
