import SwiftUI
import AppKit
import SwiftData

/// Detail pane for a selected project: header + TabView (Terminal / Skills / Worktrees).
///
/// Each `ProjectDetailView` instance owns an independent `sessionID` — swapping the
/// selected project in the sidebar creates a new instance, restarting the PTY.
/// (Deliverable 2 will keep PTYs alive across project switches via a ZStack.)
struct ProjectDetailView: View {
    @Bindable var project: ClaudeProject

    @State private var sessionID: UUID = UUID()
    @State private var selectedTab: ProjectTab = .terminal
    @State private var currentBranch: String = "—"
    @State private var headerWorktrees: [WorktreeInfo] = []

    private enum ProjectTab: String { case terminal, skills, worktrees }

    var body: some View {
        VStack(spacing: 0) {
            projectHeader
            Divider()
            TabView(selection: $selectedTab) {
                terminalView
                    .tabItem { Label("Terminal", systemImage: "terminal") }
                    .tag(ProjectTab.terminal)

                SkillsNavigatorView()
                    .tabItem { Label("Skills", systemImage: "bolt.horizontal") }
                    .tag(ProjectTab.skills)

                WorktreesView(rootDirectory: project.displayPath) { path in
                    selectedTab = .terminal
                    guard path != project.displayPath else { return }
                    project.displayPath = path
                    sessionID = UUID()
                }
                .tabItem { Label("Worktrees", systemImage: "arrow.triangle.branch") }
                .tag(ProjectTab.worktrees)
            }
        }
        .task(id: sessionID) {
            SessionStore.shared.update(
                AgentSession(sessionID: sessionID.uuidString, cwd: project.displayPath, isSynthetic: true)
            )
        }
        .onChange(of: project.displayPath) { _, newPath in
            // displayPath changed externally (e.g. cleanup replaced a stale worktree path
            // with the git root) — restart the PTY in the correct directory.
            if !FileManager.default.fileExists(atPath: newPath) { return }
            sessionID = UUID()
        }
        .task(id: project.displayPath) {
            while !Task.isCancelled {
                currentBranch = await GitStateService.shared.currentBranch(in: project.displayPath)
                headerWorktrees = await GitStateService.shared.worktrees(in: project.displayPath)
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }

    // MARK: - Header

    private var projectHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal")
                .foregroundStyle(.secondary)
            Text((project.displayPath as NSString).abbreviatingWithTildeInPath)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Menu {
                ForEach(headerWorktrees) { wt in
                    Button {
                        project.displayPath = wt.path
                        sessionID = UUID()
                    } label: {
                        Label(wt.displayName, systemImage: "arrow.triangle.branch")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                    Text(currentBranch)
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(headerWorktrees.isEmpty)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Terminal

    private var terminalView: some View {
        let escaped = project.displayPath.replacingOccurrences(of: "'", with: "'\\''")
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["HOME"] = NSHomeDirectory()
        env["CLAUDE_TERMINAL_MANAGED"] = "1"
        let envArray = env.map { "\($0.key)=\($0.value)" }
        return TerminalViewRepresentable(
            executable: "/bin/zsh",
            args: ["-l", "-i", "-c", "cd '\(escaped)' && claude"],
            environment: envArray
        )
        .id(sessionID)
    }
}
