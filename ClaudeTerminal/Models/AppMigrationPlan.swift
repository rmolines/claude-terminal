@preconcurrency import SwiftData

/// SwiftData migration plan: V1 → V2.
///
/// Uses lightweight (.inferMappingModel) migration — SwiftData automatically
/// handles adding new optional properties and new entities without a custom mapping.
/// Existing tasks get priority = nil (displayed as "medium") and project = nil
/// (displayed in the "Other" section of the sidebar).
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )
}
