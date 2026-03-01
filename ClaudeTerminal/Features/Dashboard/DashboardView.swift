import SwiftUI
import Shared

/// Main dashboard — shows all active/paused/completed agent sessions.
struct DashboardView: View {
    @State private var store = SessionStore.shared

    private var sortedSessions: [AgentSession] {
        store.sessions.values.sorted { $0.lastEventAt > $1.lastEventAt }
    }

    var body: some View {
        NavigationSplitView {
            Text("Task Backlog")
                .frame(minWidth: 200)
        } detail: {
            if sortedSessions.isEmpty {
                emptyState
            } else {
                sessionList
            }
        }
        .navigationTitle("Claude Terminal")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Claude Terminal")
                .font(.title2.bold())
            Text("No active agents")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Session list

    private var sessionList: some View {
        List(sortedSessions, id: \.sessionID) { session in
            SessionRow(session: session)
        }
    }
}

// MARK: - SessionRow

private struct SessionRow: View {
    let session: AgentSession

    var body: some View {
        HStack(spacing: 12) {
            statusIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(session.cwd)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                Text(session.sessionID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if session.status == .awaitingInput {
                Text("HITL")
                    .font(.caption.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch session.status {
        case .running:
            Image(systemName: "circle.fill")
                .foregroundStyle(.green)
        case .awaitingInput:
            Image(systemName: "circle.fill")
                .foregroundStyle(.orange)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
        case .blocked:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}
