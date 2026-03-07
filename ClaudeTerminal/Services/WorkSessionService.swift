import Foundation
import Observation

@MainActor
@Observable
final class WorkSessionService {
    static let shared = WorkSessionService()

    private(set) var workSessions: [WorkSession] = []

    private var currentRoot: String = ""
    private var timer: Timer?

    private init() {}

    // MARK: - Public API

    /// Start the background poll timer. Call once from applicationDidFinishLaunching.
    func start() {
        scheduleTimerIfNeeded()
    }

    /// Set or update the root directory to poll. Called from WorkSessionPanelView.onAppear.
    func updateRoot(_ path: String) {
        guard path != currentRoot else { return }
        currentRoot = path
        Task { await poll() }
    }

    // MARK: - Private

    private func scheduleTimerIfNeeded() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.poll() }
        }
    }

    private func poll() async {
        guard !currentRoot.isEmpty else { return }
        let root = currentRoot
        let worktrees = await GitStateService.shared.worktrees(in: root)
        let sessions = SessionStore.shared.sessions
        let projectRoot = await GitStateService.shared.gitRootPath(for: root) ?? root
        let kanban = KanbanReader.shared.load(projectPath: projectRoot)
        recompute(worktrees: worktrees, sessions: sessions, kanban: kanban)
    }

    private func recompute(
        worktrees: [WorktreeInfo],
        sessions: [String: AgentSession],
        kanban: KanbanBacklogFile?
    ) {
        var result: [WorkSession] = []
        for worktree in worktrees {
            let session = sessions.values.first {
                $0.cwd == worktree.path || $0.cwd.hasPrefix(worktree.path + "/")
            }
            let featureName = worktree.displayName
            let feature = kanban?.features.first { f in
                f.id == featureName ||
                f.branch?.contains(featureName) == true ||
                worktree.branch.contains(f.id)
            }
            result.append(WorkSession(
                id: worktree.path,
                worktree: worktree,
                session: session,
                kanbanFeature: feature
            ))
        }
        workSessions = result.sorted { $0.urgency < $1.urgency }
    }
}
