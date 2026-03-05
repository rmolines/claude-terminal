@preconcurrency import SwiftData
import Foundation

// No migration stages needed — this is a fresh store (distinct name avoids
// conflicts with any residual store from earlier DashboardView iterations).
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [] }
    static var stages: [MigrationStage] { [] }
}

extension ModelContainer {
    /// Shared container for the app. Uses a named store file so it does not
    /// conflict with stores created by earlier builds of Claude Terminal.
    static func makeShared() -> ModelContainer {
        let schema = Schema([ClaudeProject.self])
        // Build store path and ensure the parent directory exists.
        // ModelContainer does not create intermediate directories — without this,
        // the store silently falls back to in-memory and data is lost on relaunch.
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let storeDir = appSupport.appendingPathComponent("ClaudeTerminal")
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        let storeURL = storeDir.appendingPathComponent("ClaudeTerminalProjectsV1.store")
        let config = ModelConfiguration(schema: schema, url: storeURL)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
