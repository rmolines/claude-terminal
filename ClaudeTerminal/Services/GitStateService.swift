import Foundation

struct WorktreeInfo: Identifiable, Sendable {
    let id: String        // = path (unique)
    let path: String
    let branch: String

    var displayName: String {
        path.components(separatedBy: "/").last ?? path
    }
}

/// Executa queries de git de forma assíncrona sem bloquear atores.
actor GitStateService {
    static let shared = GitStateService()
    private init() {}

    /// Returns the canonical repo root for any path, including linked worktrees.
    ///
    /// Uses `--git-common-dir` (not `--show-toplevel`) so that all worktrees of the same
    /// repo resolve to the same root. `--show-toplevel` returns each worktree's own dir,
    /// causing them to appear as separate projects.
    ///
    /// If `directory` doesn't exist on disk, walks up to the nearest existing parent first.
    /// Returns nil if the path is not inside a git repository.
    func gitRootPath(for directory: String) async -> String? {
        var dir = directory
        while !FileManager.default.fileExists(atPath: dir) {
            let parent = (dir as NSString).deletingLastPathComponent
            if parent == dir { return nil }
            dir = parent
        }
        guard let raw = try? await runGit(args: ["rev-parse", "--git-common-dir"], cwd: dir),
              let commonDir = raw.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        else { return nil }

        // --git-common-dir may be relative (e.g. ".git") or absolute.
        let absolute = commonDir.hasPrefix("/")
            ? commonDir
            : (dir as NSString).appendingPathComponent(commonDir)
        // The repo root is the parent of the .git directory.
        return (absolute as NSString).deletingLastPathComponent
    }

    /// Retorna a branch atual no diretório dado. Retorna "—" em caso de erro.
    func currentBranch(in directory: String) async -> String {
        guard FileManager.default.fileExists(atPath: directory) else { return "—" }
        let output = try? await runGit(args: ["branch", "--show-current"], cwd: directory)
        return output?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "—"
    }

    /// Extrai o nome do worktree do caminho (ex: ".claude/worktrees/my-feature" → "my-feature").
    nonisolated func worktreeName(from cwd: String) -> String? {
        guard let range = cwd.range(of: ".claude/worktrees/") else { return nil }
        let after = String(cwd[range.upperBound...])
        return after.components(separatedBy: "/").first.flatMap { $0.nilIfEmpty }
    }

    /// Lists all worktrees via `git worktree list --porcelain`.
    func worktrees(in directory: String) async -> [WorktreeInfo] {
        guard FileManager.default.fileExists(atPath: directory) else { return [] }
        guard let output = try? await runGit(args: ["worktree", "list", "--porcelain"], cwd: directory) else { return [] }

        var result: [WorktreeInfo] = []
        for block in output.components(separatedBy: "\n\n") {
            var path: String?
            var branch = "detached"
            for line in block.components(separatedBy: "\n") {
                if line.hasPrefix("worktree ") {
                    path = String(line.dropFirst("worktree ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if line.hasPrefix("branch refs/heads/") {
                    branch = String(line.dropFirst("branch refs/heads/".count))
                }
            }
            if let p = path, !p.isEmpty {
                result.append(WorktreeInfo(id: p, path: p, branch: branch))
            }
        }
        return result
    }

    /// Number of modified/untracked files via `git status --short`.
    func changedFiles(in directory: String) async -> Int {
        guard FileManager.default.fileExists(atPath: directory) else { return 0 }
        guard let output = try? await runGit(args: ["status", "--short"], cwd: directory) else { return 0 }
        return output.components(separatedBy: "\n").filter { !$0.isEmpty }.count
    }

    /// Commits ahead of main (or master) via `git rev-list <base>..HEAD --count`.
    func commitsAhead(in directory: String) async -> Int {
        guard FileManager.default.fileExists(atPath: directory) else { return 0 }
        for base in ["main", "master"] {
            if let output = try? await runGit(args: ["rev-list", "\(base)..HEAD", "--count"], cwd: directory),
               let count = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return count
            }
        }
        return 0
    }

    /// Creates a new worktree at `.claude/worktrees/<name>` on branch `feature/<name>`.
    /// Returns the absolute path of the created worktree.
    func addWorktree(name: String, in rootPath: String) async throws -> String {
        // Validate: kebab-case only — block shell injection (CVE-2025-59536)
        guard name.range(of: "^[a-z][a-z0-9-]{0,48}$", options: .regularExpression) != nil else {
            throw GitError.invalidWorktreeName
        }

        let worktreePath = (rootPath as NSString)
            .appendingPathComponent(".claude/worktrees/\(name)")

        // Try main, fallback to master — same pattern as commitsAhead
        var lastError: Error = GitError.nonZeroExit(-1)
        for base in ["main", "master"] {
            do {
                _ = try await runGit(
                    args: ["worktree", "add", worktreePath, "-b", "feature/\(name)", base],
                    cwd: rootPath
                )
                return worktreePath
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    // MARK: - Private

    private func runGit(args: [String], cwd: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = args
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)
            process.environment = ["PATH": "/usr/bin:/usr/local/bin:/opt/homebrew/bin", "HOME": NSHomeDirectory()]

            let outPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = Pipe()  // discard stderr

            process.terminationHandler = { @Sendable p in
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                if p.terminationStatus == 0 {
                    continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
                } else {
                    continuation.resume(throwing: GitError.nonZeroExit(p.terminationStatus))
                }
            }

            do { try process.run() }
            catch { continuation.resume(throwing: error) }
        }
    }
}

enum GitError: Error {
    case nonZeroExit(Int32)
    case invalidWorktreeName
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
