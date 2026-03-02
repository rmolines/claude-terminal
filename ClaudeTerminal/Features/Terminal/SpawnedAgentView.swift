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
                if let skill = config.skillCommand {
                    Text(skill)
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
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
        // Use login+interactive shell (-l -i) so zsh sources both .zprofile and .zshrc,
        // giving the full user PATH (Homebrew, nvm, ~/.local/bin, etc.).
        return TerminalViewRepresentable(
            executable: "/bin/zsh",
            args: ["-l", "-i", "-c", "cd '\(escaped)' && claude"],
            environment: [
                "HOME=\(NSHomeDirectory())",
                "TERM=xterm-256color"
            ],
            initialInput: config.skillCommand
        )
    }
}

#Preview("Feature — with skill dispatch") {
    SpawnedAgentView(config: AgentTerminalConfig(
        sessionID: "preview-spawn-1",
        worktreePath: "/Users/dev/git/my-app/.claude/worktrees/auth-flow",
        taskTitle: "Implement auth flow",
        skillCommand: "/start-feature auth-flow"
    ))
}

#Preview("Fix — no skill") {
    SpawnedAgentView(config: AgentTerminalConfig(
        sessionID: "preview-spawn-2",
        worktreePath: "/Users/dev/git/my-app/.claude/worktrees/fix-crash",
        taskTitle: "Fix crash on launch",
        skillCommand: nil
    ))
}
