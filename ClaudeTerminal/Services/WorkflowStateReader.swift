import Foundation

/// Reads disk artifacts produced by skills and infers the current workflow state.
///
/// Implements Lei 1 of skill-contracts: "o artefato é o único contrato durável."
/// Designed to complement hook-based updates in WorkflowUpdateService — not replace them.
@MainActor
final class WorkflowStateReader {
    static let shared = WorkflowStateReader()
    private init() {}

    /// Reads artifacts from disk and returns inferred states keyed by skill ID.
    func inferStates(projectPath: String) async -> [String: WorkflowNodeState] {
        var states: [String: WorkflowNodeState] = [:]
        let fm = FileManager.default
        let dotClaude = "\(projectPath)/.claude"
        let featurePlansDir = "\(dotClaude)/feature-plans"

        // /explore — explore.md exists at repo root
        if fm.fileExists(atPath: "\(projectPath)/explore.md") {
            states["/explore"] = .done
        }

        // Parse backlog.json once; used for multiple checks below
        let backlog = loadBacklog(at: "\(dotClaude)/backlog.json")

        // /plan-roadmap — backlog.json has at least one milestone
        if let b = backlog, !b.milestones.isEmpty {
            states["/plan-roadmap"] = .done
        }

        // /start-milestone — any sprint.md exists inside .claude/feature-plans/
        if containsFile(named: "sprint.md", in: featurePlansDir, fm: fm) {
            states["/start-milestone"] = .done
        }

        // /start-feature — check artifacts, then backlog status, then git branch
        let hasPlanMd = containsFile(named: "plan.md", in: featurePlansDir, fm: fm)
        let hasDiscoveryMd = containsFile(named: "discovery.md", in: featurePlansDir, fm: fm)

        if hasPlanMd {
            states["/start-feature"] = .done
        } else if hasDiscoveryMd {
            states["/start-feature"] = .activeOrAwaiting
        } else {
            // Fallback: check git branch pattern
            let branch = await GitStateService.shared.currentBranch(in: projectPath)
            if branch.hasPrefix("feature/") || branch.hasPrefix("worktree-") {
                states["/start-feature"] = .activeOrAwaiting
            }
        }

        // backlog: feature with status in-progress → /start-feature was done (feature started)
        if let b = backlog, b.features.contains(where: { $0.status == "in-progress" }) {
            states["/start-feature"] = .done
        }

        // /validate — commits ahead of main signals pending validation
        let commits = await GitStateService.shared.commitsAhead(in: projectPath)
        if commits > 0, (states["/validate"] ?? .notStarted) == .notStarted {
            states["/validate"] = .activeOrAwaiting
        }

        // /ship-feature and /close-feature — inferred from backlog prNumber
        if let b = backlog {
            if b.features.contains(where: { $0.prNumber != nil && $0.status == "done" }) {
                states["/ship-feature"] = .done
                states["/close-feature"] = .done
            } else if b.features.contains(where: { $0.prNumber != nil && $0.status == "in-progress" }) {
                states["/ship-feature"] = .activeOrAwaiting
            }
        }

        return states
    }

    // MARK: - Private helpers

    private func loadBacklog(at path: String) -> BacklogFile? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return try? JSONDecoder().decode(BacklogFile.self, from: data)
    }

    /// Returns true if a file with `filename` exists anywhere inside `directory` (recursive).
    private func containsFile(named filename: String, in directory: String, fm: FileManager) -> Bool {
        guard let enumerator = fm.enumerator(atPath: directory) else { return false }
        for case let item as String in enumerator {
            if (item as NSString).lastPathComponent == filename { return true }
        }
        return false
    }
}

// MARK: - Backlog JSON structs (private)

private struct BacklogFile: Decodable {
    let milestones: [BacklogMilestone]
    let features: [BacklogFeature]

    // Tolerate missing keys so partial backlog.json files still parse
    private enum CodingKeys: String, CodingKey { case milestones, features }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        milestones = (try? c.decode([BacklogMilestone].self, forKey: .milestones)) ?? []
        features = (try? c.decode([BacklogFeature].self, forKey: .features)) ?? []
    }
}

private struct BacklogMilestone: Decodable {
    let id: String
}

private struct BacklogFeature: Decodable {
    let id: String
    let status: String    // "pending" | "in-progress" | "done"
    let prNumber: Int?
}
