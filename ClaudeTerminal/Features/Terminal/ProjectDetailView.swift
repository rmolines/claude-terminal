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
    /// Revision token per path — bumping forces SwiftUI to destroy and recreate the terminal.
    @State private var terminalRevision: [String: UUID] = [:]
    /// Paths where the PTY process has exited — shows "session ended" overlay.
    @State private var deadPaths: Set<String> = []
    /// Initial input to inject once per path — consumed on first terminal creation; cleared on restart.
    @State private var pendingInitialInput: [String: String] = [:]
    @State private var selectedTab: ProjectTab = .terminal
    @State private var currentBranch: String = "—"
    @State private var headerWorktrees: [WorktreeInfo] = []

    private enum ProjectTab: String { case terminal, skills, worktrees, workflow, kanban, sessions }

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

                WorktreesView(rootDirectory: project.displayPath) { path, initialInput in
                    selectedTab = .terminal
                    project.displayPath = path
                    openPath(path, initialInput: initialInput)
                }
                .tabItem { Label("Worktrees", systemImage: "arrow.triangle.branch") }
                .tag(ProjectTab.worktrees)

                WorkflowGraphView(project: project)
                    .tabItem { Label("Workflow", systemImage: "point.3.connected.trianglepath.dotted") }
                    .tag(ProjectTab.workflow)

                KanbanView(projectPath: project.path)
                    .tabItem { Label("Kanban", systemImage: "rectangle.split.3x1") }
                    .tag(ProjectTab.kanban)

                WorkSessionPanelView(rootDirectory: project.displayPath)
                    .tabItem { Label("Sessions", systemImage: "square.stack.3d.up") }
                    .tag(ProjectTab.sessions)
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
            Button {
                restartCurrentTerminal()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .help("Restart Claude")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Terminal

    private var terminalView: some View {
        ZStack {
            ForEach(openedPaths, id: \.self) { path in
                ZStack {
                    makeTerminal(for: path)
                        .id("\(path)-\(terminalRevision[path]?.uuidString ?? "initial")")
                    if deadPaths.contains(path) {
                        sessionEndedOverlay(for: path)
                    }
                }
                .opacity(project.displayPath == path ? 1 : 0)
                .allowsHitTesting(project.displayPath == path)
            }
        }
    }

    private func sessionEndedOverlay(for path: String) -> some View {
        ZStack {
            Color.black.opacity(0.6)
            VStack(spacing: 12) {
                Image(systemName: "terminal")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text("Session ended")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Button("Restart") {
                    deadPaths.remove(path)
                    pendingInitialInput.removeValue(forKey: path)
                    terminalRevision[path] = UUID()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
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

        // Load snapshot once — delete immediately so it's not shown again unless re-saved on quit.
        var restoreContent: (data: Data, savedAt: Date)? = nil
        if let data = TerminalSnapshotStore.shared.load(projectID: project.id, path: path) {
            let savedAt = snapshotModificationDate(projectID: project.id, path: path)
            restoreContent = (data: data, savedAt: savedAt)
            TerminalSnapshotStore.shared.delete(projectID: project.id, path: path)
        }

        let deadPathsBinding = $deadPaths
        return TerminalViewRepresentable(
            executable: "/bin/zsh",
            args: ["-l", "-i", "-c", "cd '\(escaped)' && claude"],
            environment: envArray,
            initialInput: pendingInitialInput[path],
            projectID: project.id,
            path: path,
            restoreContent: restoreContent,
            onProcessTerminated: {
                var current = deadPathsBinding.wrappedValue
                current.insert(path)
                deadPathsBinding.wrappedValue = current
            }
        )
    }

    /// Returns the modification date of the snapshot file, falling back to now.
    private func snapshotModificationDate(projectID: UUID, path: String) -> Date {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var hash: UInt64 = 5381
        for byte in path.utf8 { hash = hash &* 31 &+ UInt64(byte) }
        let hashStr = String(hash, radix: 16, uppercase: false)
        let file = support
            .appendingPathComponent("ClaudeTerminal/snapshots")
            .appendingPathComponent(projectID.uuidString)
            .appendingPathComponent(hashStr)
            .appendingPathComponent("terminal.dat")
        let attrs = try? FileManager.default.attributesOfItem(atPath: file.path)
        return (attrs?[.modificationDate] as? Date) ?? Date()
    }

    // MARK: - Helpers

    private func restartCurrentTerminal() {
        let path = project.displayPath
        deadPaths.remove(path)
        pendingInitialInput.removeValue(forKey: path)
        // Bump the revision — SwiftUI will destroy the old terminal view (closing the PTY)
        // and create a new one. No snapshot is saved, so the new session starts clean.
        terminalRevision[path] = UUID()
    }

    private func openPath(_ path: String, initialInput: String? = nil) {
        if !openedPaths.contains(path) {
            openedPaths.append(path)
        }
        if let input = initialInput, !input.isEmpty {
            pendingInitialInput[path] = input
        }
        SessionStore.shared.update(
            AgentSession(sessionID: "synthetic-\(path)", cwd: path, isSynthetic: true)
        )
    }
}
