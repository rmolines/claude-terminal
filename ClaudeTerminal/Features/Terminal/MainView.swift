import SwiftUI
import AppKit

/// Main window: a single Claude terminal starting in the user's home directory.
///
/// The header shows the current working directory and a button to switch folders.
/// Changing the directory restarts the PTY via `.id(sessionID)`.
struct MainView: View {
    @State private var workingDirectory: String = NSHomeDirectory()
    @State private var sessionID: UUID = UUID()
    @State private var selectedTab: AppTab = .terminal

    private enum AppTab: String {
        case terminal, skills
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            terminalTab
                .tabItem { Label("Terminal", systemImage: "terminal") }
                .tag(AppTab.terminal)

            SkillsNavigatorView()
                .tabItem { Label("Skills", systemImage: "bolt.horizontal") }
                .tag(AppTab.skills)
        }
        .frame(minWidth: 700, minHeight: 400)
        .task(id: sessionID) {
            // Register the terminal session immediately so Skills tab works without waiting for a hook.
            // Uses sessionID as stable key; replaced when folder changes (new sessionID).
            SessionStore.shared.update(AgentSession(sessionID: sessionID.uuidString, cwd: workingDirectory))
        }
    }

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
        workingDirectory = url.path
        sessionID = UUID()  // forces PTY recreation via .id()
    }
}

#Preview {
    MainView()
        .frame(width: 900, height: 600)
}
