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
    }
}
