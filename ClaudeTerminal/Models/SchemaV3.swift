import Foundation
import SwiftData

/// V3 schema — adds the Bet entity for the Bet Bowl feature.
///
/// Lightweight migration contract (what SwiftData does on migrated V2 stores):
/// - `Bet` rows → none (new entity, starts empty — table is created from scratch)
///
/// No inner frozen classes are needed here: Bet did not exist in the V2 store,
/// so there is no entity-name mismatch to guard against. SwiftData creates the
/// new table automatically via lightweight migration.
enum SchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [ClaudeTask.self, ClaudeAgent.self, ClaudeProject.self, Bet.self]
    }
}
