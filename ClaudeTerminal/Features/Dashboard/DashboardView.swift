import SwiftUI

/// Main dashboard — shows all active/paused/completed agent sessions.
struct DashboardView: View {
    var body: some View {
        NavigationSplitView {
            Text("Task Backlog")
                .frame(minWidth: 200)
        } detail: {
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
        .navigationTitle("Claude Terminal")
    }
}
