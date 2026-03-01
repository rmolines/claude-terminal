import SwiftUI
import Shared

/// Main dashboard — shows all active/paused/completed agent sessions.
struct DashboardView: View {
    private let store = SessionStore.shared
    @State private var selectedSessionID: String?
    @State private var showNewAgent = false

    private var sortedSessions: [AgentSession] {
        store.sessions.values.sorted { $0.lastEventAt > $1.lastEventAt }
    }

    private var selectedSession: AgentSession? {
        guard let id = selectedSessionID else { return nil }
        return store.sessions[id]
    }

    var body: some View {
        NavigationSplitView {
            TaskBacklogView()
                .frame(minWidth: 240)
        } content: {
            List(sortedSessions, id: \.sessionID, selection: $selectedSessionID) { session in
                SessionRow(session: session)
            }
        } detail: {
            if let session = selectedSession {
                AgentTerminalView(session: session)
            } else {
                emptyState
            }
        }
        .navigationTitle("Claude Terminal")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showNewAgent = true } label: {
                    Label("New Agent", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewAgent) {
            NewAgentSheet()
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Claude Terminal")
                .font(.title2.bold())
            Text("Select an agent session to open a terminal")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - SessionRow

private struct SessionRow: View {
    let session: AgentSession

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            HStack(spacing: 12) {
                statusIcon
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(session.cwd)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        Text(formatElapsed(session.startedAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    HStack(spacing: 6) {
                        if let activity = session.currentActivity {
                            Text(activity)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else {
                            Text(session.sessionID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        tokenBadge
                        if session.subAgentCount > 0 {
                            Text("×\(session.subAgentCount) sub")
                                .font(.caption.bold())
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.gray.opacity(0.2))
                                .foregroundStyle(.secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
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
                }
            }
            .padding(.vertical, 4)
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

    private func formatElapsed(_ from: Date) -> String {
        let s = Int(Date().timeIntervalSince(from))
        if s < 60 { return "\(s)s" }
        let m = s / 60; let sec = s % 60
        if m < 60 { return "\(m)m \(sec)s" }
        return "\(m / 60)h \(m % 60)m"
    }
}
