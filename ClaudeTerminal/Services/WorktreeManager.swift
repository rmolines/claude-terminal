import Foundation

/// Manages git worktrees for agent session isolation.
///
/// Each agent creates its own worktree so N sessions can run on the same repo in parallel.
/// Branch naming: claude/<task-title>_<nanoseconds> — timestamp suffix guarantees uniqueness.
actor WorktreeManager {
    static let shared = WorktreeManager()

    private let worktreeBaseDir: URL = {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("ClaudeTerminal")
            .appendingPathComponent("worktrees")
    }()

    private init() {}

    /// Creates a new worktree for the given task.
    /// Returns the worktree path and the created branch name, or nil on failure.
    func createWorktree(repoPath: String, taskTitle: String) async -> (path: String, branch: String)? {
        let sanitizedTitle = taskTitle
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }

        let branchName = "claude/\(sanitizedTitle)_\(DispatchTime.now().uptimeNanoseconds)"
        let worktreePath = worktreeBaseDir
            .appendingPathComponent(branchName.replacingOccurrences(of: "/", with: "-"))
            .path

        let result = await runGit(
            args: ["worktree", "add", "-b", branchName, worktreePath, "HEAD"],
            in: repoPath
        )
        guard result.exitCode == 0 else { return nil }
        return (worktreePath, branchName)
    }

    /// Removes a worktree and its branch.
    func removeWorktree(repoPath: String, worktreePath: String, branchName: String) async {
        _ = await runGit(args: ["worktree", "remove", "-f", worktreePath], in: repoPath)
        _ = await runGit(args: ["worktree", "prune"], in: repoPath)
        _ = await runGit(args: ["branch", "-D", branchName], in: repoPath)
    }

    /// Prunes stale worktrees on app startup.
    func pruneStaleWorktrees(repoPath: String) async {
        _ = await runGit(args: ["worktree", "prune"], in: repoPath)
    }

    // MARK: - Private

    private func runGit(args: [String], in directory: String) async -> (exitCode: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        // Security: no shell interpolation, args as array, no env passthrough beyond minimum
        process.environment = ["PATH": "/usr/bin:/bin", "HOME": NSHomeDirectory()]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (-1, error.localizedDescription)
        }

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        return (process.terminationStatus, output)
    }
}
