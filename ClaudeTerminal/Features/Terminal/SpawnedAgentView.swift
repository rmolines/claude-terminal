import SwiftUI
import AppKit

/// Window body for a spawned agent session.
///
/// Opens a PTY running `zsh -c "cd '<worktree>' && claude"` in the agent's worktree.
/// `.id(config.sessionID)` forces PTY recreation if the window group reuses the view.
struct SpawnedAgentView: View {
    let config: AgentTerminalConfig

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            terminal
                .id(config.sessionID)
        }
        .frame(minWidth: 700, minHeight: 400)
        .navigationTitle(config.taskTitle)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(config.taskTitle)
                    .font(.body.bold())
                    .lineLimit(1)
                Text(config.worktreePath)
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
        let escaped = config.worktreePath.replacingOccurrences(of: "'", with: "'\\''")
        return TerminalViewRepresentable(
            executable: "/bin/zsh",
            args: ["-c", "cd '\(escaped)' && claude"],
            environment: [
                "PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin",
                "HOME=\(NSHomeDirectory())",
                "TERM=xterm-256color"
            ]
        )
    }
}
