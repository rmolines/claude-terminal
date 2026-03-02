import Foundation
import SwiftData
import SwiftUI

// Note: Named ClaudeTask (not Task) to avoid conflict with Swift Concurrency's Task type.

@Model
final class ClaudeTask {
    var id: UUID
    var title: String
    var taskType: String  // "feature" | "fix" | "project"
    var status: String    // AgentStatus rawValue
    var priority: String  // "urgent" | "high" | "medium" | "low"
    var createdAt: Date
    var sortOrder: Int    // SwiftData does not preserve array ordering — always sort manually

    @Relationship(deleteRule: .cascade, inverse: \ClaudeAgent.task)
    var agents: [ClaudeAgent]?

    // No @Relationship decorator here — inverse is declared on ClaudeProject.tasks
    var project: ClaudeProject?

    init(title: String, taskType: String, priority: String = "medium") {
        self.id = UUID()
        self.title = title
        self.taskType = taskType
        self.priority = priority
        self.status = "running"
        self.createdAt = Date()
        self.sortOrder = 0
    }

    /// Sort key for priority: urgent=0, high=1, medium=2, low=3
    var prioritySortKey: Int {
        switch priority {
        case "urgent": return 0
        case "high":   return 1
        case "low":    return 3
        default:       return 2  // "medium" and any legacy empty-string from V1 migration
        }
    }

    /// Display label and SwiftUI color for this task's priority.
    ///
    /// Single source of truth — used by TaskRow, NewAgentSheet, and any future views.
    /// Note: SwiftUI's Color cannot be stored in SwiftData, so this is a computed property.
    var priorityDisplay: (label: String, color: SwiftUI.Color) {
        switch priority {
        case "urgent": return ("P0", .red)
        case "high":   return ("P1", .orange)
        case "low":    return ("P3", .secondary)
        default:       return ("P2", .init(red: 0.85, green: 0.6, blue: 0.0))
        }
    }
}
