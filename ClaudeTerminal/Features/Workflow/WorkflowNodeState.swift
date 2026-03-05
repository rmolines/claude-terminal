import Foundation

/// Persisted state for a single workflow node. Stored as values in `ClaudeProject.workflowStatesJSON`.
enum WorkflowNodeState: String, Codable {
    /// Skill has not been invoked yet.
    case notStarted
    /// Skill was invoked and is active or awaiting user input.
    case activeOrAwaiting
    /// Skill completed successfully (fingerprint detected).
    case done
}

/// Computed state used for rendering. Adds `anomaly` for nodes that appear done
/// but whose prerequisites are not all done.
enum RenderedNodeState {
    case notStarted
    case activeOrAwaiting
    case done
    /// Node is marked done but at least one prerequisite is not done — likely a state inconsistency.
    case anomaly
}
