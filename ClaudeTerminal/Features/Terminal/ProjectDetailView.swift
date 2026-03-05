import SwiftUI
import AppKit
import SwiftData

/// Detail pane for a selected project: header + TabView (Terminal / Skills / Worktrees).
///
/// Multiple worktree terminals are kept alive in a ZStack — switching paths
/// only changes visibility, never destroys the PTY process.
struct ProjectDetailView: View {
    @Bindable var project: ClaudeProject

    /// Paths whose terminals have been opened this session — kept alive in ZStack.
    @State private var openedPaths: [String] = []
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
                    project.displayPath = path
                    openPath(path)
                }
                .tabItem { Label("Worktrees", systemImage: "arrow.triangle.branch") }
                .tag(ProjectTab.worktrees)
            }
        }
        .onAppear {
            openPath(project.displayPath)
        }
        .onChange(of: project.displayPath) { _, newPath in
            // displayPath changed externally (e.g. cleanup replaced a stale worktree path
            // with the git root) — open a terminal for the new path if it doesn't exist yet.
            guard FileManager.default.fileExists(atPath: newPath) else { return }
            openPath(newPath)
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
                        openPath(wt.path)
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
        ZStack {
            ForEach(openedPaths, id: \.self) { path in
                makeTerminal(for: path)
                    .opacity(project.displayPath == path ? 1 : 0)
                    .allowsHitTesting(project.displayPath == path)
            }
        }
    }

    private func makeTerminal(for path: String) -> TerminalViewRepresentable {
        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
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
    }

    // MARK: - Helpers

    private func openPath(_ path: String) {
        if !openedPaths.contains(path) {
            openedPaths.append(path)
        }
        SessionStore.shared.update(
            AgentSession(sessionID: "synthetic-\(path)", cwd: path, isSynthetic: true)
        )
    }
}
