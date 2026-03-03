import SwiftUI
import AppKit

/// A standalone Claude Code session window opened without a task or agent.
///
/// Runs `zsh -l -i -c "cd '<dir>' && claude"` — login+interactive for full user PATH.
/// Passes `replyRoutingCwd` to the terminal so the reply box in AgentCardView
/// can send text directly into this PTY via NotificationCenter.
/// Use `.id(config.id)` in the WindowGroup to force PTY recreation per window.
struct QuickAgentView: View {
    let config: QuickAgentConfig

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
            Image(systemName: "brain.head.profile")
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
            args: ["-l", "-i", "-c", "cd '\(escaped)' && claude"],
            environment: [
                "HOME=\(NSHomeDirectory())",
                "TERM=xterm-256color"
            ],
            replyRoutingCwd: config.directoryPath
        )
    }
}

#Preview("Quick Agent") {
    QuickAgentView(config: QuickAgentConfig(directoryPath: "/Users/dev/git/my-app"))
}
