import SwiftUI
import AppKit

@main
struct ClaudeTerminalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("Claude Terminal") {
            MainView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    appDelegate.updaterController?.checkForUpdates(nil)
                }
            }
        }
    }
}
