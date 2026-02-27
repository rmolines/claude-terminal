import SwiftUI
import AppKit

@main
struct ClaudeTerminalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("Claude Terminal") {
            DashboardView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
