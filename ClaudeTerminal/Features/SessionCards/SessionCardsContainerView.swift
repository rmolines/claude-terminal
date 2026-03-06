import SwiftUI
import SwiftData
import Shared

/// Cross-project dashboard: session cards grouped by project, updated every second via a single TimelineView.
/// Only shows projects that have an open terminal tab in the app (openedProjectIDs).
struct SessionCardsContainerView: View {
    /// IDs of projects with open terminal tabs — limits the dashboard to what the user has open.
    let openedProjectIDs: Set<PersistentIdentifier>

    @Query(sort: \ClaudeProject.sortOrder) var projects: [ClaudeProject]

    private var openProjects: [ClaudeProject] {
        projects.filter { openedProjectIDs.contains($0.persistentModelID) }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            content(now: context.date)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let projectsWithSessions = projectsHavingSessions()
        if projectsWithSessions.isEmpty {
            ContentUnavailableView(
                "No Active Sessions",
                systemImage: "terminal",
                description: Text("Start a Claude Code session to see it here.")
            )
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                    ForEach(projectsWithSessions, id: \.persistentModelID) { project in
                        projectSection(project: project, now: now)
                    }
                }
                .padding(16)
            }

        }
    }

    @ViewBuilder
    private func projectSection(project: ClaudeProject, now: Date) -> some View {
        let sessions = activeSessions(for: project)
        if !sessions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                projectHeader(project: project, count: sessions.count)
                ForEach(sessions, id: \.sessionID) { session in
                    SessionCardView(
                        session: session,
                        projectName: project.name,
                        now: now
                    )
                }
            }
        }
    }

    private func projectHeader(project: ClaudeProject, count: Int) -> some View {
        HStack(spacing: 6) {
            Label(project.name, systemImage: "folder")
                .font(.subheadline)
                .fontWeight(.semibold)
            if count > 1 {
                Text("\(count)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
            Spacer()
        }
    }

    // MARK: - Session filtering

    private func activeSessions(for project: ClaudeProject) -> [AgentSession] {
        // Real sessions that haven't sent an event in 15 minutes are likely stale (process killed
        // without a Stop hook). Synthetic sessions (idle terminal tabs) are always shown.
        let staleThreshold = Date().addingTimeInterval(-15 * 60)
        return SessionStore.shared.sessions.values
            .filter { session in
                session.status != .completed &&
                session.status != .blocked &&
                (session.cwd.hasPrefix(project.path) || session.cwd.hasPrefix(project.displayPath)) &&
                (session.isSynthetic || session.lastEventAt > staleThreshold)
            }
            .sorted { $0.startedAt < $1.startedAt }
    }

    private func projectsHavingSessions() -> [ClaudeProject] {
        openProjects.filter { !activeSessions(for: $0).isEmpty }
    }
}
