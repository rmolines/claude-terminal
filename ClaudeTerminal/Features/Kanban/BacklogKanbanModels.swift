import Foundation

// MARK: - Top-level container

struct KanbanBacklogFile: Decodable {
    let milestones: [KanbanMilestone]
    let features: [KanbanFeature]

    private enum CodingKeys: String, CodingKey { case milestones, features }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        milestones = (try? c.decode([KanbanMilestone].self, forKey: .milestones)) ?? []
        features = (try? c.decode([KanbanFeature].self, forKey: .features)) ?? []
    }
}

// MARK: - Milestone

struct KanbanMilestone: Decodable, Identifiable {
    let id: String
    let name: String
    let status: String    // "planned" | "active" | "done"

    private enum CodingKeys: String, CodingKey { case id, name, status }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id     = (try? c.decode(String.self, forKey: .id))     ?? ""
        name   = (try? c.decode(String.self, forKey: .name))   ?? ""
        status = (try? c.decode(String.self, forKey: .status)) ?? "planned"
    }
}

// MARK: - Feature

struct KanbanFeature: Decodable, Identifiable {
    let id: String
    let title: String
    let status: KanbanStatus
    let milestone: String
    let prNumber: Int?
    let branch: String?
    let labels: [String]
    let sortOrder: Int?
    let createdAt: String?
    let updatedAt: String?

    private enum CodingKeys: String, CodingKey {
        case id, title, status, milestone, prNumber, branch, labels, sortOrder, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = (try? c.decode(String.self, forKey: .id))        ?? ""
        title      = (try? c.decode(String.self, forKey: .title))     ?? ""
        milestone  = (try? c.decode(String.self, forKey: .milestone)) ?? ""
        prNumber   = try? c.decodeIfPresent(Int.self,    forKey: .prNumber)
        branch     = try? c.decodeIfPresent(String.self, forKey: .branch)
        labels     = (try? c.decode([String].self, forKey: .labels))  ?? []
        sortOrder  = try? c.decodeIfPresent(Int.self,    forKey: .sortOrder)
        createdAt  = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt  = try? c.decodeIfPresent(String.self, forKey: .updatedAt)

        let rawStatus = (try? c.decode(String.self, forKey: .status)) ?? "pending"
        status = KanbanStatus(rawValue: rawStatus) ?? .pending
    }
}

// MARK: - Status enum

enum KanbanStatus: String, CaseIterable {
    case pending      = "pending"
    case inProgress   = "in-progress"
    case done         = "done"

    var columnTitle: String {
        switch self {
        case .pending:    return "Todo"
        case .inProgress: return "Doing"
        case .done:       return "Done"
        }
    }
}

// MARK: - Reader

@MainActor
final class KanbanReader {
    static let shared = KanbanReader()
    private init() {}

    func load(projectPath: String) -> KanbanBacklogFile? {
        let path = "\(projectPath)/.claude/backlog.json"
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return try? JSONDecoder().decode(KanbanBacklogFile.self, from: data)
    }
}
