import Foundation

struct SkillEntry: Identifiable, Sendable {
    let id: String          // full file path (unique)
    let name: String
    let description: String
    let filePath: String
    let kind: SkillKind
}

enum SkillKind: String, Sendable, CaseIterable {
    case autoTrigger    = "Auto-trigger"
    case globalCommand  = "Global command"
    case projectCommand = "Project command"
}
