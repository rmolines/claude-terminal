import SwiftUI
import AppKit
import Shared

/// Detail pane showing a shell terminal in the agent's working directory.
///
/// Spawns `/bin/zsh` via `cd && exec zsh` — not attached to the agent's own process.
/// `.id(session.sessionID)` on the terminal forces PTY recreation when the selection changes.
struct AgentTerminalView: View {
    let session: AgentSession

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            terminal
                .id(session.sessionID)
        }
    }

    // MARK: - Header

    private var header: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            HStack(spacing: 10) {
                statusIcon
                Text(session.cwd)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                tokenBadge
                Text(formatElapsed(session.startedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }

    // MARK: - Terminal

    private var terminal: some View {
        // Single-quote escape: replace ' with '\'' so the path is safe inside 'cd '...''.
        let escaped = session.cwd.replacingOccurrences(of: "'", with: "'\\''")
        return TerminalViewRepresentable(
            executable: "/bin/zsh",
            args: ["-c", "cd '\(escaped)' && exec zsh"],
            environment: [
                "PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin",
                "HOME=\(NSHomeDirectory())",
                "TERM=xterm-256color"
            ]
        )
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var statusIcon: some View {
        switch session.status {
        case .running:
            Image(systemName: "circle.fill").foregroundStyle(.green)
        case .awaitingInput:
            Image(systemName: "circle.fill").foregroundStyle(.orange)
        case .completed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.secondary)
        case .blocked:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var tokenBadge: some View {
        let total = session.totalInputTokens + session.totalOutputTokens
        if total > 0 {
            let cost = Double(session.totalInputTokens) * 3.0 / 1_000_000
                     + Double(session.totalOutputTokens) * 15.0 / 1_000_000
                     + Double(session.totalCacheReadTokens) * 0.30 / 1_000_000
            let tokLabel = total >= 1000
                ? String(format: "%.1fk tok", Double(total) / 1000)
                : "\(total) tok"
            Text("\(tokLabel) · \(String(format: "$%.2f", cost))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func formatElapsed(_ from: Date) -> String {
        let s = Int(Date().timeIntervalSince(from))
        if s < 60 { return "\(s)s" }
        let m = s / 60; let sec = s % 60
        if m < 60 { return "\(m)m \(sec)s" }
        return "\(m / 60)h \(m % 60)m"
    }
}
