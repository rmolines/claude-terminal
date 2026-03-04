import SwiftUI

/// Aba "Skills" — mostra cards por agente ativo com as skills recomendadas para o próximo passo.
struct SkillsNavigatorView: View {
    private let store = SessionStore.shared

    @State private var branchBySession: [String: String] = [:]

    private var sessions: [AgentSession] {
        store.sessions.values.sorted { $0.startedAt < $1.startedAt }
    }

    var body: some View {
        Group {
            if sessions.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(sessions, id: \.sessionID) { session in
                            AgentWorkflowCard(
                                session: session,
                                branch: branchBySession[session.sessionID] ?? "—"
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
        .task(id: sessions.map(\.sessionID).joined()) {
            // Runs on first appearance and whenever the session set changes.
            await refreshBranches()
        }
    }

    // MARK: - Branch polling

    private func refreshBranches() async {
        for session in sessions {
            let branch = await GitStateService.shared.currentBranch(in: session.cwd)
            branchBySession[session.sessionID] = branch
        }
        // Poll every 15 seconds
        try? await Task.sleep(nanoseconds: 15_000_000_000)
        if !Task.isCancelled {
            await refreshBranches()
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.horizontal.circle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Nenhum agente ativo")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Inicie uma sessão Claude Code no Terminal\npara ver as skills disponíveis aqui.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SkillsNavigatorView()
        .frame(width: 500, height: 400)
}
