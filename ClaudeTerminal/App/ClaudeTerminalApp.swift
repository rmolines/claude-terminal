import SwiftUI
import AppKit
import SwiftData

@main
struct ClaudeTerminalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let sharedContainer: ModelContainer = .makeShared()

    var body: some Scene {
        WindowGroup("Claude Terminal") {
            MainView()
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
    }
}
