import Foundation
import SwiftData

/// A lightweight idea capture — a "bet" in Shape Up vocabulary.
///
/// Bets are intentionally minimal: just a title and optional notes.
/// They live in the "Bet Bowl" section of the sidebar and can be drawn
/// randomly to decide what to build next. A drawn bet is either converted
/// into a ClaudeTask or dismissed back to the pool.
///
/// Status lifecycle: "draft" → "converted" (via BetDrawSheet).
/// "draft" bets appear in the bowl; "converted" bets are archived.
@Model
final class Bet {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String?
    var status: String = "draft"       // "draft" | "converted"
    var createdAt: Date = Date()
    var convertedTaskID: UUID?         // weak link to ClaudeTask after conversion
    var sortOrder: Int = 0

    init(title: String, notes: String? = nil) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.createdAt = Date()
        self.sortOrder = 0
    }
}
