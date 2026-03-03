import SwiftUI
import AppKit
import SwiftTerm

/// NSViewRepresentable wrapper for SwiftTerm's LocalProcessTerminalView.
///
/// Each instance uses its own DispatchQueue — never share DispatchQueue.main
/// across multiple terminal views (causes UI lag with 4+ active agents).
///
/// In Xcode Previews the PTY is replaced with a static placeholder — the env var
/// `XCODE_RUNNING_FOR_PREVIEWS=1` is set by Xcode automatically.
struct TerminalViewRepresentable: NSViewRepresentable {
    let executable: String
    let args: [String]
    let environment: [String]?
    var initialInput: String? = nil
    var replyRoutingCwd: String? = nil

    /// True when running inside the Xcode canvas (set automatically by Xcode 26.3+).
    static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    // Each instance gets an isolated queue for background parsing
    private let queue = DispatchQueue(
        label: "com.rmolines.ClaudeTerminal.terminal.\(UUID().uuidString)",
        qos: .userInteractive
    )

    func makeNSView(context: Context) -> NSView {
        // Return a static placeholder in the Xcode canvas — spawning a PTY crashes previews.
        if Self.isPreview {
            let container = NSView(frame: .zero)
            container.wantsLayer = true
            container.layer?.backgroundColor = NSColor.black.cgColor
            let label = NSTextField(labelWithString: "[ terminal — not available in preview ]")
            label.textColor = .systemGreen
            label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            label.alignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])
            return container
        }

        let tv = LocalProcessTerminalView(frame: .zero)
        tv.processDelegate = context.coordinator

        tv.startProcess(
            executable: executable,
            args: args,
            environment: environment,
            execName: nil
        )

        if let input = initialInput {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak tv] in
                guard let tv else { return }
                let bytes = Array((input + "\n").utf8)
                tv.send(data: bytes[...])
            }
        }

        if let cwd = replyRoutingCwd {
            let obs = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ClaudeTerminal.SessionReply"),
                object: nil,
                queue: .main
            ) { [weak tv] notification in
                guard let userInfo = notification.userInfo,
                      let notifCwd = userInfo["cwd"] as? String,
                      notifCwd == cwd,
                      let text = userInfo["text"] as? String else { return }
                let bytes = Array((text + "\n").utf8)
                MainActor.assumeIsolated {
                    tv?.send(data: bytes[...])
                }
            }
            context.coordinator.inputObserver = obs
        }

        return tv
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // SwiftTerm manages its own state — no updates needed from SwiftUI bindings.
        // Placeholder NSView is static — no updates needed either.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: LocalProcessTerminalViewDelegate {
        var inputObserver: NSObjectProtocol?

        deinit {
            if let obs = inputObserver {
                NotificationCenter.default.removeObserver(obs)
            }
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func processTerminated(source: TerminalView, exitCode: Int32?) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    }
}
