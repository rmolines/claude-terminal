import Foundation
import SwiftTerm

/// Tracks live terminal coordinators so AppDelegate can capture scrollback on quit.
///
/// Uses weak references — coordinators unregister automatically on deinit.
@MainActor
final class TerminalRegistry {
    static let shared = TerminalRegistry()

    // MARK: - Entry

    private struct Entry {
        let projectID: UUID
        let path: String
        weak var coordinator: TerminalViewRepresentable.Coordinator?
    }

    private var entries: [String: Entry] = [:]   // key = path

    private init() {}

    // MARK: - Public API

    func register(path: String, projectID: UUID, coordinator: TerminalViewRepresentable.Coordinator) {
        entries[path] = Entry(projectID: projectID, path: path, coordinator: coordinator)
    }

    func unregister(path: String) {
        entries.removeValue(forKey: path)
    }

    /// Captures scrollback from all live terminals.
    /// Returns `(projectID, path, content)` tuples for use at quit time.
    func captureAll() -> [(projectID: UUID, path: String, data: Data)] {
        var result: [(projectID: UUID, path: String, data: Data)] = []
        for entry in entries.values {
            guard let coordinator = entry.coordinator,
                  let data = coordinator.captureContent(),
                  !data.isEmpty else { continue }
            result.append((projectID: entry.projectID, path: entry.path, data: data))
        }
        return result
    }
}
