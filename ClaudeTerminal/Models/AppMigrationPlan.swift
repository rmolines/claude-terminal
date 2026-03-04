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
        let storeURL = URL.applicationSupportDirectory
            .appending(component: "ClaudeTerminal", directoryHint: .isDirectory)
            .appending(component: "ClaudeTerminalProjectsV1.store")
        let config = ModelConfiguration(schema: schema, url: storeURL)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
