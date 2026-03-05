import Foundation
import SwiftData

/// Updates workflow state in `ClaudeProject` based on IPC events (slash commands and bash fingerprints).
///
/// Runs on @MainActor — `ModelContext` is not thread-safe.
@MainActor
@Observable
final class WorkflowUpdateService {
    static let shared = WorkflowUpdateService()

    private let context: ModelContext

    private init() {
        context = ModelContext(ModelContainer.makeShared())
    }

    // MARK: - Public API

    /// Marks `skillID` as `.activeOrAwaiting` for the project that owns `cwd`.
    func markActive(skillID: String, forProjectAt cwd: String) {
        guard let project = findProject(cwd: cwd) else { return }
        var states = project.workflowStates
        states[skillID] = .activeOrAwaiting
        project.workflowStates = states
        project.currentSkillID = skillID
        project.lastWorkflowUpdate = Date()
        save()
    }

    /// Checks a bash command against known fingerprints and marks the matching skill as `.done`.
    func applyBashFingerprint(_ command: String, forProjectAt cwd: String) {
        guard let skillID = fingerprint(for: command),
              let project = findProject(cwd: cwd) else { return }
        var states = project.workflowStates
        states[skillID] = .done
        project.workflowStates = states
        project.lastWorkflowUpdate = Date()
        save()
    }

    /// Reads disk artifacts for `project` and merges the inferred states into the store.
    ///
    /// Merge rule: `done` (disk) > `activeOrAwaiting` > `notStarted`.
    /// Reader state never regresses a hook state — hooks are more recent for active skills.
    func syncFromDisk(project: ClaudeProject) async {
        let inferred = await WorkflowStateReader.shared.inferStates(projectPath: project.path)

        // Find the corresponding object in this service's ModelContext to avoid cross-context writes.
        guard let managed = findProject(cwd: project.path) else { return }

        var current = managed.workflowStates
        var changed = false
        for (skillID, readerState) in inferred {
            let hookState = current[skillID] ?? .notStarted
            let merged = mergeState(reader: readerState, hook: hookState)
            if merged != hookState {
                current[skillID] = merged
                changed = true
            }
        }

        if changed {
            managed.workflowStates = current
            managed.lastWorkflowUpdate = Date()
            save()
        }
    }

    // MARK: - Private

    /// Returns the higher-priority state: done > activeOrAwaiting > notStarted.
    private func mergeState(reader: WorkflowNodeState, hook: WorkflowNodeState) -> WorkflowNodeState {
        let priority: [WorkflowNodeState: Int] = [.notStarted: 0, .activeOrAwaiting: 1, .done: 2]
        return (priority[reader] ?? 0) >= (priority[hook] ?? 0) ? reader : hook
    }

    /// Maps a bash command prefix to a skill ID it signals completion for.
    private func fingerprint(for command: String) -> String? {
        let fingerprints: [(prefix: String, skillID: String)] = [
            ("gh pr create", "/ship-feature"),
            ("gh api repos/", "/ship-feature"),
            ("git worktree remove", "/close-feature"),
            ("gh pr merge", "/close-feature"),
            ("swift build", "/validate"),
            ("make check", "/validate"),
        ]
        for entry in fingerprints {
            if command.hasPrefix(entry.prefix) { return entry.skillID }
        }
        return nil
    }

    /// Finds the `ClaudeProject` whose `path` is a prefix of `cwd` (handles worktrees).
    private func findProject(cwd: String) -> ClaudeProject? {
        let descriptor = FetchDescriptor<ClaudeProject>()
        guard let projects = try? context.fetch(descriptor) else { return nil }
        // Prefer the longest matching path (most specific).
        return projects
            .filter { cwd == $0.path || cwd.hasPrefix($0.path + "/") }
            .max(by: { $0.path.count < $1.path.count })
    }

    private func save() {
        try? context.save()
    }
}
