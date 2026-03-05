@preconcurrency import SwiftData
import Foundation

// MARK: - Schema V1 (snapshot of original schema — 7 fields)

enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [ClaudeProject.self] }

    // Inner class MUST be named ClaudeProject (not ClaudeProjectV1) to match
    // the entity name recorded in the store. The enum namespace is sufficient.
    @Model
    final class ClaudeProject {
        var id: UUID = UUID()
        var name: String = ""
        var path: String = ""
        var displayPath: String = ""
        var createdAt: Date = Date()
        var sortOrder: Int = 0
        var statusRaw: String = "idle"

        init() {}
    }
}

// MARK: - Schema V2 (adds workflow state fields)

enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(2, 0, 0) }
    static var models: [any PersistentModel.Type] { [ClaudeProject.self] }

    @Model
    final class ClaudeProject {
        var id: UUID = UUID()
        var name: String = ""
        var path: String = ""
        var displayPath: String = ""
        var createdAt: Date = Date()
        var sortOrder: Int = 0
        var statusRaw: String = "idle"
        var workflowStatesJSON: String = "{}"
        var currentSkillID: String? = nil
        var lastWorkflowUpdate: Date? = nil

        init() {}
    }
}

// MARK: - Migration plan

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] {
        [MigrationStage.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}

// MARK: - Shared container

extension ModelContainer {
    /// Shared container for the app. Uses a named store file so it does not
    /// conflict with stores created by earlier builds of Claude Terminal.
    static func makeShared() -> ModelContainer {
        let schema = Schema([ClaudeProject.self])
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let storeDir = appSupport.appendingPathComponent("ClaudeTerminal")
        // ModelContainer does not create intermediate directories — without this
        // the store silently falls back to in-memory and data is lost on relaunch.
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        let storeURL = storeDir.appendingPathComponent("ClaudeTerminalProjectsV1.store")
        let config = ModelConfiguration(schema: schema, url: storeURL)
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: AppMigrationPlan.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
