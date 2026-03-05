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
    var projectID: UUID? = nil
    var path: String? = nil
    var restoreContent: (data: Data, savedAt: Date)? = nil

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

        // Wire coordinator for snapshot capture
        context.coordinator.terminalView = tv
        if let pid = projectID, let p = path {
            context.coordinator.projectID = pid
            context.coordinator.path = p
            TerminalRegistry.shared.register(path: p, projectID: pid, coordinator: context.coordinator)
        }

        // Restore previous session scrollback if available
        if let restore = restoreContent {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak tv] in
                guard let tv else { return }
                let bytes = [UInt8](restore.data)
                tv.terminal.feed(buffer: bytes[...])
                let df = DateFormatter()
                df.dateStyle = .medium
                df.timeStyle = .short
                let divider = "\r\n\u{1B}[2m\u{2500}\u{2500} Session restored \(df.string(from: restore.savedAt)) \u{2500}\u{2500}\u{1B}[0m\r\n\r\n"
                tv.terminal.feed(text: divider)
            }
        }

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
        var projectID: UUID?
        var path: String?
        weak var terminalView: LocalProcessTerminalView?

        deinit {
            if let obs = inputObserver {
                NotificationCenter.default.removeObserver(obs)
            }
            if let p = path {
                Task { @MainActor in TerminalRegistry.shared.unregister(path: p) }
            }
        }

        /// Captures the current terminal buffer content, trimming trailing blank lines.
        @MainActor func captureContent() -> Data? {
            guard let tv = terminalView else { return nil }
            let raw = tv.terminal.getBufferAsData()
            guard var text = String(data: raw, encoding: .utf8) else { return raw }
            var lines = text.components(separatedBy: "\n")
            while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
                lines.removeLast()
            }
            text = lines.joined(separator: "\n")
            return text.data(using: .utf8)
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func processTerminated(source: TerminalView, exitCode: Int32?) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    }
}
