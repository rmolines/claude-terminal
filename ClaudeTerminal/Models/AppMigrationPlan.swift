@preconcurrency import SwiftData

/// SwiftData migration plan: V1 → V2 → V3.
///
/// Uses lightweight (.inferMappingModel) migration throughout — SwiftData automatically
/// handles adding new optional properties and new entities without a custom mapping.
/// V1→V2: existing tasks get priority = "" (treated as "medium") and project = nil.
/// V2→V3: adds the Bet entity (new table, starts empty).
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )

    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self
    )
}
