import Foundation
import Shared

enum UrgencyTier: Int, Comparable {
    case hitlPending = 0
    case error       = 1
    case running     = 2
    case done        = 3
    case idle        = 4

    static func < (lhs: UrgencyTier, rhs: UrgencyTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct WorkSession: Identifiable {
    /// Stable identity across poll cycles — worktree path is unique per repo.
    let id: String
    let worktree: WorktreeInfo
    var session: AgentSession?
    var kanbanFeature: KanbanFeature?

    var urgency: UrgencyTier {
        guard let session else { return .idle }
        switch session.status {
        case .awaitingInput: return .hitlPending
        case .blocked:       return .error
        case .running:       return .running
        case .completed:     return .done
        }
    }

    var displayTitle: String {
        kanbanFeature?.title ?? worktree.displayName
    }
}
