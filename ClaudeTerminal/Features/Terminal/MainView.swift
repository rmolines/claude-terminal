import SwiftUI
import AppKit

/// Main window: a single Claude terminal starting in the user's home directory.
///
/// On first launch (no saved directory), shows a directory picker.
/// On subsequent launches, goes straight to the terminal using the last saved directory.
/// The header shows the current working directory and a button to switch folders.
/// Changing the directory restarts the PTY via `.id(sessionID)`.
struct MainView: View {
    @AppStorage("workingDirectory") private var workingDirectory: String = ""
    @AppStorage("recentDirectoriesData") private var recentDirectoriesData: String = ""
    @State private var sessionID: UUID = UUID()
    @State private var selectedTab: AppTab = .terminal
    @State private var currentBranch: String = "—"
    @State private var headerWorktrees: [WorktreeInfo] = []

    private enum AppTab: String {
        case terminal, skills, worktrees
    }

    private var recentDirectories: [String] {
        guard let data = recentDirectoriesData.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }

    var body: some View {
        if workingDirectory.isEmpty {
            directoryPicker
                .frame(minWidth: 500, minHeight: 350)
        } else {
            TabView(selection: $selectedTab) {
                terminalTab
                    .tabItem { Label("Terminal", systemImage: "terminal") }
                    .tag(AppTab.terminal)

                SkillsNavigatorView()
                    .tabItem { Label("Skills", systemImage: "bolt.horizontal") }
                    .tag(AppTab.skills)

                WorktreesView(rootDirectory: workingDirectory) { path in
                    selectDirectory(path)
                    selectedTab = .terminal
                }
                .tabItem { Label("Worktrees", systemImage: "arrow.triangle.branch") }
                .tag(AppTab.worktrees)
            }
            .frame(minWidth: 700, minHeight: 400)
            .task(id: sessionID) {
                // Register the terminal session immediately so Skills tab works without waiting for a hook.
                // Uses sessionID as stable key; replaced when folder changes (new sessionID).
                SessionStore.shared.update(AgentSession(sessionID: sessionID.uuidString, cwd: workingDirectory, isSynthetic: true))
            }
            .task(id: workingDirectory) {
                guard !workingDirectory.isEmpty else { return }
                while !Task.isCancelled {
                    currentBranch = await GitStateService.shared.currentBranch(in: workingDirectory)
                    headerWorktrees = await GitStateService.shared.worktrees(in: workingDirectory)
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                }
            }
        }
    }

    // MARK: - Directory Picker

    private var directoryPicker: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "display")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Claude Terminal")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Choose a folder to start working in")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !recentDirectories.isEmpty {
                List(recentDirectories, id: \.self) { dir in
                    Button(action: { selectDirectory(dir) }) {
                        Label((dir as NSString).abbreviatingWithTildeInPath, systemImage: "folder")
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.bordered)
                .frame(maxWidth: 380, maxHeight: 150)
            }

            Button(action: pickFolder) {
                Label("Browse…", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Terminal Tab

    private var terminalTab: some View {
        VStack(spacing: 0) {
            header
            Divider()
            terminal
                .id(sessionID)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal")
                .foregroundStyle(.secondary)
            Text((workingDirectory as NSString).abbreviatingWithTildeInPath)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Menu {
                ForEach(headerWorktrees) { wt in
                    Button {
                        selectDirectory(wt.path)
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
            Button(action: pickFolder) {
                Label("Open Folder…", systemImage: "folder")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Terminal

    private var terminal: some View {
        // Single-quote escape so path is safe inside zsh -c 'cd '...''
        let escaped = workingDirectory.replacingOccurrences(of: "'", with: "'\\''")
        // Inherit the full parent process environment so claude finds its credentials
        // (Keychain access, ANTHROPIC_API_KEY, etc.), then override TERM for compatibility.
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

    // MARK: - Actions

    private func selectDirectory(_ path: String) {
        addToRecents(path)
        workingDirectory = path
        sessionID = UUID()
    }

    /// Opens a folder picker. Called directly (no Task/await) because views are @MainActor
    /// and NSOpenPanel.runModal() blocks the run loop correctly.
    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Choose Working Directory"
        panel.prompt = "Open"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        selectDirectory(url.path)
    }

    private func addToRecents(_ path: String) {
        var recents = recentDirectories
        recents.removeAll { $0 == path }
        recents.insert(path, at: 0)
        recents = Array(recents.prefix(5))
        if let data = try? JSONEncoder().encode(recents),
           let string = String(data: data, encoding: .utf8) {
            recentDirectoriesData = string
        }
    }
}

#Preview {
    MainView()
        .frame(width: 900, height: 600)
}
