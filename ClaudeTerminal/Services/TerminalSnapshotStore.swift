import Foundation

/// Persists terminal scrollback content across app launches.
///
/// Snapshots are keyed by `(projectID, path)` and stored as raw UTF-8 data.
/// Storage path: `~/Library/Application Support/ClaudeTerminal/snapshots/<projectID>/<pathHash>/terminal.dat`
@MainActor
final class TerminalSnapshotStore {
    static let shared = TerminalSnapshotStore()

    private let base: URL

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        base = support.appendingPathComponent("ClaudeTerminal/snapshots", isDirectory: true)
    }

    func save(projectID: UUID, path: String, content: Data) throws {
        let dir = snapshotDir(projectID: projectID, path: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("terminal.dat")
        // Atomic write — avoids partial writes on crash
        try content.write(to: file, options: .atomic)
    }

    func load(projectID: UUID, path: String) -> Data? {
        let file = snapshotDir(projectID: projectID, path: path).appendingPathComponent("terminal.dat")
        return try? Data(contentsOf: file)
    }

    func delete(projectID: UUID, path: String) {
        let file = snapshotDir(projectID: projectID, path: path).appendingPathComponent("terminal.dat")
        try? FileManager.default.removeItem(at: file)
    }

    // MARK: - Private

    private func snapshotDir(projectID: UUID, path: String) -> URL {
        let hash = pathHash(path)
        return base
            .appendingPathComponent(projectID.uuidString, isDirectory: true)
            .appendingPathComponent(hash, isDirectory: true)
    }

    private func pathHash(_ path: String) -> String {
        // Simple stable hash — not cryptographic, just for directory naming
        var hash: UInt64 = 5381
        for byte in path.utf8 {
            hash = hash &* 31 &+ UInt64(byte)
        }
        return String(hash, radix: 16, uppercase: false)
    }
}
