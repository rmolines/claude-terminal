import SwiftUI
import SwiftData
import AppKit

/// Sheet for spawning a new Claude Code agent on a backlog task.
///
/// Flow:
/// 1. Pick a pending task from the backlog.
/// 2. Choose a git repo path.
/// 3. Tap "Spawn Agent" — creates a worktree, saves ClaudeAgent to SwiftData, opens terminal window.
struct NewAgentSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    @Query(sort: \ClaudeTask.sortOrder) private var allTasks: [ClaudeTask]

    @State private var selectedTask: ClaudeTask?
    @State private var repoPath = ""
    @State private var isSpawning = false
    @State private var spawnError: String?

    private var pendingTasks: [ClaudeTask] {
        allTasks.filter { $0.status != "completed" }
    }

    private var canSpawn: Bool {
        selectedTask != nil
            && !repoPath.isEmpty
            && FileManager.default.fileExists(atPath: repoPath)
            && !isSpawning
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("New Agent")
                .font(.title2.bold())

            // Task picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Task").font(.headline)
                if pendingTasks.isEmpty {
                    Text("No pending tasks — add tasks in the backlog first.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else {
                    Picker("Task", selection: $selectedTask) {
                        Text("Select a task…").tag(Optional<ClaudeTask>.none)
                        ForEach(pendingTasks) { task in
                            Text(task.title).tag(Optional(task))
                        }
                    }
                    .labelsHidden()
                }
            }

            // Repo path
            VStack(alignment: .leading, spacing: 6) {
                Text("Repository path").font(.headline)
                HStack {
                    TextField("/path/to/repo", text: $repoPath)
                        .font(.system(.body, design: .monospaced))
                    Button("Browse…") { browseForRepo() }
                }
                if !repoPath.isEmpty && !FileManager.default.fileExists(atPath: repoPath) {
                    Text("Path not found.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            // Error banner
            if let error = spawnError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.primary)
                }
                .padding(10)
                .background(.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()

            // Actions
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    Task { await spawnAgent() }
                } label: {
                    if isSpawning {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Spawning…")
                        }
                    } else {
                        Text("Spawn Agent")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSpawn)
            }
        }
        .padding(24)
        .frame(width: 480, height: 340)
    }

    // MARK: - Actions

    private func browseForRepo() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Select Git Repository"
        if panel.runModal() == .OK, let url = panel.url {
            repoPath = url.path
        }
    }

    private func spawnAgent() async {
        guard let task = selectedTask else { return }
        isSpawning = true
        spawnError = nil

        // 1. Create worktree
        guard let (worktreePath, branchName) = await WorktreeManager.shared.createWorktree(
            repoPath: repoPath,
            taskTitle: task.title
        ) else {
            spawnError = "Failed to create git worktree. Ensure the path is a valid git repository."
            isSpawning = false
            return
        }

        // 2. Save ClaudeAgent to SwiftData
        let sessionID = UUID().uuidString
        let agent = ClaudeAgent(sessionID: sessionID)
        agent.worktreePath = worktreePath
        agent.branchName = branchName
        agent.task = task
        context.insert(agent)
        try? context.save()

        // 3. Open agent terminal window
        let config = AgentTerminalConfig(
            sessionID: sessionID,
            worktreePath: worktreePath,
            taskTitle: task.title
        )
        openWindow(id: "agent-terminal", value: config)

        dismiss()
    }
}
