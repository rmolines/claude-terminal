import SwiftUI
import AppKit

/// A standalone shell window opened without a task or agent.
///
/// Runs `zsh -l -i -c "cd '<dir>' && exec zsh"` — login+interactive for full user PATH.
/// Use `.id(config.id)` in the WindowGroup to force PTY recreation per window.
struct QuickTerminalView: View {
    let config: QuickTerminalConfig

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            terminal
                .id(config.id)
        }
        .frame(minWidth: 700, minHeight: 400)
        .navigationTitle(config.displayTitle)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(config.displayTitle)
                    .font(.body.bold())
                    .lineLimit(1)
                Text(config.directoryPath)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Terminal

    private var terminal: some View {
        // Single-quote escape: replace ' with '\'' so the path is safe inside 'cd '...''.
        let escaped = config.directoryPath.replacingOccurrences(of: "'", with: "'\\''")
        return TerminalViewRepresentable(
            executable: "/bin/zsh",
            args: ["-l", "-i", "-c", "cd '\(escaped)' && exec zsh"],
            environment: [
                "HOME=\(NSHomeDirectory())",
                "TERM=xterm-256color"
            ]
        )
    }
}

#Preview("Quick Terminal") {
    QuickTerminalView(config: QuickTerminalConfig(directoryPath: "/Users/dev/git/my-app"))
}
