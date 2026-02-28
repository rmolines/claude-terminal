import SwiftUI
import AppKit
import SwiftTerm

/// NSViewRepresentable wrapper for SwiftTerm's LocalProcessTerminalView.
///
/// Each instance uses its own DispatchQueue — never share DispatchQueue.main
/// across multiple terminal views (causes UI lag with 4+ active agents).
struct TerminalViewRepresentable: NSViewRepresentable {
    let executable: String
    let args: [String]
    let environment: [String]?

    // Each instance gets an isolated queue for background parsing
    private let queue = DispatchQueue(
        label: "com.rmolines.ClaudeTerminal.terminal.\(UUID().uuidString)",
        qos: .userInteractive
    )

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let tv = LocalProcessTerminalView(frame: .zero)
        tv.processDelegate = context.coordinator

        tv.startProcess(
            executable: executable,
            args: args,
            environment: environment,
            execName: nil
        )

        return tv
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // SwiftTerm manages its own state — no updates needed from SwiftUI bindings
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: LocalProcessTerminalViewDelegate {
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func processTerminated(source: TerminalView, exitCode: Int32?) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    }
}
