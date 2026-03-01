import SwiftUI
import AppKit
import SwiftData

@main
struct ClaudeTerminalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("Claude Terminal") {
            DashboardView()
        }
        .modelContainer(for: [ClaudeTask.self, ClaudeAgent.self])
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        WindowGroup("Agent", id: "agent-terminal", for: AgentTerminalConfig.self) { $config in
            if let c = config {
                SpawnedAgentView(config: c)
            }
        }
        .modelContainer(for: [ClaudeTask.self, ClaudeAgent.self])
    }
}
