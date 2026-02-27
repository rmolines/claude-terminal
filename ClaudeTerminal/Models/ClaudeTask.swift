import Foundation
import SwiftData

// Note: Named ClaudeTask (not Task) to avoid conflict with Swift Concurrency's Task type.

@Model
final class ClaudeTask {
    var id: UUID
    var title: String
    var taskType: String  // "feature" | "fix" | "project"
    var status: String    // AgentStatus rawValue
    var createdAt: Date
    var sortOrder: Int    // SwiftData does not preserve array ordering — always sort manually

    @Relationship(deleteRule: .cascade, inverse: \ClaudeAgent.task)
    var agents: [ClaudeAgent]?

    init(title: String, taskType: String) {
        self.id = UUID()
        self.title = title
        self.taskType = taskType
        self.status = "running"
        self.createdAt = Date()
        self.sortOrder = 0
    }
}
