import SwiftUI

struct WorkSessionPanelView: View {
    let rootDirectory: String
    private let service = WorkSessionService.shared

    var body: some View {
        Group {
            if service.workSessions.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .onAppear {
            service.updateRoot(rootDirectory)
        }
        .onChange(of: rootDirectory) { _, newRoot in
            service.updateRoot(newRoot)
        }
    }

    // MARK: - Subviews

    private var list: some View {
        List(service.workSessions) { ws in
            WorkSessionRowView(workSession: ws)
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No active worktrees")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    WorkSessionPanelView(rootDirectory: NSHomeDirectory())
        .frame(width: 400, height: 300)
}
