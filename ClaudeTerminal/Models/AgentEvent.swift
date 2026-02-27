import Foundation

// Note: AgentEvent (in-memory) is intentionally NOT a @Model.
// Event streams have high insert frequency — use Core Data or GRDB directly,
// not SwiftData (known performance issues with bulk inserts).
//
// This file defines the in-memory representation used by SessionManager.

struct AgentEventRecord: Identifiable, Sendable {
    let id: UUID
    let sessionID: String
    let type: String
    let timestamp: Date

    init(sessionID: String, type: String) {
        self.id = UUID()
        self.sessionID = sessionID
        self.type = type
        self.timestamp = Date()
    }
}
