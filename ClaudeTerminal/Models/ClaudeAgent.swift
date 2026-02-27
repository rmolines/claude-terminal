import Foundation
import SwiftData

@Model
final class ClaudeAgent {
    var id: UUID
    var sessionID: String  // Claude Code session_id from hooks
    var status: String     // AgentStatus rawValue
    var worktreePath: String?
    var branchName: String?
    var baseCommitSHA: String?
    var startedAt: Date
    var completedAt: Date?
    var sortOrder: Int

    // Relationships — always var, always optional (SwiftData requirement)
    var task: ClaudeTask?

    init(sessionID: String) {
        self.id = UUID()
        self.sessionID = sessionID
        self.status = "running"
        self.startedAt = Date()
        self.sortOrder = 0
    }
}
