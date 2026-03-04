import SwiftUI

/// Aba "Worktrees" — visão macro de todas as branches abertas, estado git e sessão ativa.
struct WorktreesView: View {
    let rootDirectory: String
    let onSelect: (String) -> Void

    @State private var worktrees: [WorktreeInfo] = []
    @State private var enriched: [String: (changedFiles: Int, commitsAhead: Int)] = [:]
    private let store = SessionStore.shared

    var body: some View {
        Group {
            if worktrees.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .task(id: rootDirectory) {
            guard !rootDirectory.isEmpty else { return }
            while !Task.isCancelled {
                // Pass 1 (fast): list worktrees with branches
                let wts = await GitStateService.shared.worktrees(in: rootDirectory)
                worktrees = wts

                // Pass 2 (parallel): enrich each worktree with git stats
                await withTaskGroup(of: (String, Int, Int).self) { group in
                    for wt in wts {
                        group.addTask {
                            async let changed = GitStateService.shared.changedFiles(in: wt.path)
                            async let ahead = GitStateService.shared.commitsAhead(in: wt.path)
                            return (wt.id, await changed, await ahead)
                        }
                    }
                    for await (id, changed, ahead) in group {
                        enriched[id] = (changedFiles: changed, commitsAhead: ahead)
                    }
                }

                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }

    // MARK: - Subviews

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(worktrees) { wt in
                    WorktreeRow(
                        worktree: wt,
                        changedFiles: enriched[wt.id]?.changedFiles,
                        commitsAhead: enriched[wt.id]?.commitsAhead,
                        hasSession: hasSession(for: wt),
                        onSelect: { onSelect(wt.path) }
                    )
                    Divider()
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("Nenhum worktree encontrado")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func hasSession(for wt: WorktreeInfo) -> Bool {
        store.sessions.values.contains {
            $0.cwd.hasPrefix(wt.path) || wt.path.hasPrefix($0.cwd)
        }
    }
}

// MARK: - WorktreeRow

private struct WorktreeRow: View {
    let worktree: WorktreeInfo
    let changedFiles: Int?
    let commitsAhead: Int?
    let hasSession: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    private var phase: WorkflowPhase {
        WorkflowPhase.infer(branch: worktree.branch, cwd: worktree.path)
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(hasSession ? Color.green : Color.secondary.opacity(0.3))
                .frame(width: 6, height: 6)

            Text(worktree.displayName)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
                .lineLimit(1)

            Text(worktree.branch)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(phaseColor.opacity(0.15))
                .foregroundStyle(phaseColor)
                .clipShape(Capsule())
                .lineLimit(1)

            Spacer()

            if let ahead = commitsAhead, ahead > 0 {
                Text("\(ahead)↑")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let changed = changedFiles {
                if changed > 0 {
                    Text("\(changed) changed")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else {
                    Text("clean")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background(isHovered ? Color.accentColor.opacity(0.08) : Color.clear)
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
    }

    private var phaseColor: Color {
        switch phase {
        case .strategic: return .blue
        case .featureActive: return .purple
        case .readyToShip: return .green
        case .unknown: return .gray
        }
    }
}

#Preview {
    WorktreesView(rootDirectory: NSHomeDirectory()) { _ in }
        .frame(width: 500, height: 400)
}
