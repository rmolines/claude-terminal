import SwiftUI
import AppKit
import SwiftData

@main
struct ClaudeTerminalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// Shared model container — includes migration plan for V1→V2.
    ///
    /// `try!` is intentional: the app cannot function without its database and
    /// a crash on launch with a readable stack trace is preferable to a corrupted
    /// or missing data state. Preview containers skip this (they use isStoredInMemoryOnly).
    private let sharedContainer: ModelContainer = {
        let schema = Schema([ClaudeTask.self, ClaudeAgent.self, ClaudeProject.self])
        return try! ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self)
    }()

    var body: some Scene {
        WindowGroup("Claude Terminal") {
            DashboardView()
        }
        .modelContainer(sharedContainer)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    appDelegate.updaterController?.checkForUpdates(nil)
                }
            }
        }

        WindowGroup("Agent", id: "agent-terminal", for: AgentTerminalConfig.self) { $config in
            if let c = config {
                SpawnedAgentView(config: c)
            }
        }
        .modelContainer(sharedContainer)

        WindowGroup("Terminal", id: "quick-terminal", for: QuickTerminalConfig.self) { $config in
            if let c = config {
                QuickTerminalView(config: c)
            }
        }
    }
}
