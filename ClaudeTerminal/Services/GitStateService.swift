import Foundation

/// Executa queries de git de forma assíncrona sem bloquear atores.
actor GitStateService {
    static let shared = GitStateService()
    private init() {}

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
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
