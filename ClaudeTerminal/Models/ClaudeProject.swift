import Foundation
import SwiftData

/// A git repository (or any directory) tracked as a workspace in Claude Terminal.
///
/// `path` is the git root of the repository — so three worktrees of the same repo
/// all share the same `ClaudeProject`. `displayPath` holds the last active cwd
/// (the specific worktree the user most recently used).
@Model
final class ClaudeProject {
    var id: UUID
    var name: String           // basename of git root, editable by user
    var path: String           // absolute git root path (primary grouping key)
    var displayPath: String    // last active cwd (may be a worktree subdirectory)
    var createdAt: Date
    var sortOrder: Int         // SwiftData does not preserve array ordering
    var statusRaw: String      // "idle" | "running" | "awaiting"

    // MARK: - Workflow state (added in SchemaV2)
    /// JSON-encoded [String: WorkflowNodeState] keyed by skill ID (e.g. "/start-feature").
    var workflowStatesJSON: String = "{}"
    /// The skill ID that was most recently activated.
    var currentSkillID: String? = nil
    /// Timestamp of the last workflow state change.
    var lastWorkflowUpdate: Date? = nil

    var status: ProjectStatus {
        get { ProjectStatus(rawValue: statusRaw) ?? .idle }
        set { statusRaw = newValue.rawValue }
    }

    /// Decoded workflow states. Returns empty dict on decode failure.
    var workflowStates: [String: WorkflowNodeState] {
        get {
            guard let data = workflowStatesJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String: WorkflowNodeState].self, from: data)
            else { return [:] }
            return decoded
        }
        set {
            let data = (try? JSONEncoder().encode(newValue)) ?? Data("{}".utf8)
            workflowStatesJSON = String(data: data, encoding: .utf8) ?? "{}"
        }
    }

    init(name: String, path: String, displayPath: String? = nil) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.displayPath = displayPath ?? path
        self.createdAt = Date()
        self.sortOrder = 0
        self.statusRaw = ProjectStatus.idle.rawValue
    }
}

enum ProjectStatus: String {
    case idle = "idle"
    case running = "running"
    case awaiting = "awaiting"
}
