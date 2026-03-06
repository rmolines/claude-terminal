import SwiftUI
import Shared

/// Individual session card: header identity + current activity + token summary.
struct SessionCardView: View {
    let session: AgentSession
    let projectName: String
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SessionCardHeaderView(session: session, projectName: projectName, now: now)
            Divider()
            activityRow
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator, lineWidth: 1)
        )
    }

    // MARK: - Activity row

    private var activityRow: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 3) {
                activityContent
                if let lastMsg = session.recentMessages.first {
                    Text(lastMsg)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }
            Spacer()
            if totalTokens > 0 {
                tokenBadge
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var activityContent: some View {
        if let activity = session.currentActivity {
            Text(activity)
                .font(.system(.caption, design: activity.hasPrefix("$") ? .monospaced : .default))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .truncationMode(.tail)
        } else if session.recentMessages.isEmpty {
            Text("Idle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var tokenBadge: some View {
        if totalTokens > 0 {
            Text(formatTokens(totalTokens))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(Capsule())
        }
    }

    private var totalTokens: Int {
        session.totalInputTokens + session.totalOutputTokens
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM tok", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fK tok", Double(n) / 1_000) }
        return "\(n) tok"
    }
}

#Preview {
    var session = AgentSession(sessionID: "abc-123", cwd: "/Users/me/repo")
    session.currentActivity = "$ swift build -c release"
    session.totalInputTokens = 45_200
    session.totalOutputTokens = 3_100
    return SessionCardView(session: session, projectName: "claude-terminal", now: Date())
        .frame(width: 320)
        .padding()
}
