import SwiftUI
import SwiftData
import Shared

/// Main dashboard — shows all active/paused/completed agent sessions as an adaptive card grid.
struct DashboardView: View {
    private let store = SessionStore.shared
    @State private var showNewAgent = false
    @State private var showOnboarding = false
    @State private var hookStatus: HookInstallStatus = .notInstalled
    @State private var showSkillRegistry = false
    @Environment(\.openWindow) private var openWindow

    private var sortedSessions: [AgentSession] {
        store.sessions.values.sorted { $0.lastEventAt > $1.lastEventAt }
    }

    var body: some View {
        NavigationSplitView {
            TaskBacklogView()
                .frame(minWidth: 240)
        } detail: {
            Group {
                if sortedSessions.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 280))],
                            spacing: 12
                        ) {
                            ForEach(sortedSessions, id: \.sessionID) { session in
                                AgentCardView(session: session)
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .navigationTitle("Claude Terminal")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                if hookStatus != .installed {
                    Button { showOnboarding = true } label: {
                        Label("Hooks not set up", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    .help("Claude Code hooks are not installed. Click to set up.")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showSkillRegistry = true } label: {
                    Label("Skills", systemImage: "sparkles")
                }
                .help("Browse installed skills and commands")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { openQuickTerminal() } label: {
                    Label("Terminal", systemImage: "terminal")
                }
                .help("Open a shell in any directory without creating a task")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { openQuickAgent() } label: {
                    Label("New Session", systemImage: "brain.head.profile")
                }
                .help("Open a new Claude Code session in any directory")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showNewAgent = true } label: {
                    Label("New Agent", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showSkillRegistry) {
            SkillRegistryView(projectCwds: sortedSessions.map(\.cwd))
        }
        .sheet(isPresented: $showNewAgent) {
            NewAgentSheet()
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(hookStatus: $hookStatus) {
                showOnboarding = false
            }
        }
        .task {
            hookStatus = (try? await SettingsWriter.shared.hookInstallStatus()) ?? .notInstalled
            if hookStatus != .installed {
                showOnboarding = true
            }
        }
    }

    // MARK: - Quick agent / terminal

    private func openQuickAgent() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Select Project Directory"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openWindow(id: "quick-agent", value: QuickAgentConfig(directoryPath: url.path))
    }

    private func openQuickTerminal() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Select Directory"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openWindow(id: "quick-terminal", value: QuickTerminalConfig(directoryPath: url.path))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Claude Terminal")
                .font(.title2.bold())
            Text("Start a Claude Code session in any terminal to see it here")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

@MainActor
private func populateSampleSessions() {
    let store = SessionStore.shared
    var s1 = AgentSession(sessionID: "prev-1", cwd: "/Users/dev/git/claude-terminal/.claude/worktrees/agent-card-ui")
    s1.status = .running
    s1.currentActivity = "$ swift build -c release"
    s1.totalInputTokens = 48_200
    s1.totalOutputTokens = 12_400
    s1.subAgentCount = 2
    store.update(s1)

    var s2 = AgentSession(sessionID: "prev-2", cwd: "/Users/dev/git/my-app/.claude/worktrees/fix-crash")
    s2.status = .awaitingInput
    s2.currentActivity = "Agent wants to run: rm -rf .build && swift build"
    s2.totalInputTokens = 9_800
    s2.totalOutputTokens = 3_100
    store.update(s2)

    var s3 = AgentSession(sessionID: "prev-3", cwd: "/Users/dev/git/api-service")
    s3.status = .completed
    s3.currentActivity = "Completed"
    s3.totalInputTokens = 120_500
    s3.totalOutputTokens = 41_200
    store.update(s3)

    var s4 = AgentSession(sessionID: "prev-4", cwd: "/Users/dev/git/agent-os/.claude/worktrees/github-skill")
    s4.status = .running
    s4.currentActivity = "Editing SkillRegistryView.swift"
    s4.totalInputTokens = 22_100
    s4.totalOutputTokens = 8_300
    store.update(s4)
}

#Preview("Dashboard — 4 sessions") {
    DashboardView()
        .modelContainer(
            try! ModelContainer(
                for: ClaudeTask.self, ClaudeAgent.self, ClaudeProject.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        )
        .frame(width: 1000, height: 600)
        .task { populateSampleSessions() }
}

#Preview("Dashboard — empty") {
    DashboardView()
        .modelContainer(
            try! ModelContainer(
                for: ClaudeTask.self, ClaudeAgent.self, ClaudeProject.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        )
        .frame(width: 1000, height: 600)
        .task {
            SessionStore.shared.sessions.keys.forEach { SessionStore.shared.remove(sessionID: $0) }
        }
}
