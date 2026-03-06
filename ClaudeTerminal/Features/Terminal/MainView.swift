import SwiftUI
import AppKit
import SwiftData
import Shared

/// Root view: sidebar of ClaudeProject entities + terminal detail for the selected project.
///
/// On first launch (no projects, no legacy directory), shows a directory picker.
/// On subsequent launches, auto-selects the first project.
/// Legacy @AppStorage data is migrated to SwiftData on first run.
struct MainView: View {
    @Query(sort: \ClaudeProject.sortOrder) var projects: [ClaudeProject]
    @Environment(\.modelContext) var modelContext
    @State private var selectedProject: ClaudeProject?
    /// Projects whose terminals have been opened this session — kept alive in ZStack.
    @State private var openedProjectIDs: [PersistentIdentifier] = []
    /// True when the "All Sessions" dashboard is selected instead of a specific project.
    @State private var showDashboard = false

    // Legacy storage — read once for migration, not written after migration
    @AppStorage("workingDirectory") private var legacyWorkingDirectory: String = ""
    @AppStorage("recentDirectoriesData") private var legacyRecentDirectoriesData: String = ""

    var body: some View {
        if projects.isEmpty && legacyWorkingDirectory.isEmpty {
            firstLaunchPicker
                .frame(minWidth: 500, minHeight: 350)
        } else {
            NavigationSplitView {
                projectSidebar
            } detail: {
                // Outer ZStack keeps terminals alive even when dashboard is shown.
                // Never gate the terminal ZStack behind an if/else — that destroys PTY processes.
                ZStack {
                    if openedProjectIDs.isEmpty && !showDashboard {
                        ContentUnavailableView("Select a Project", systemImage: "folder")
                    } else {
                        // Inner ZStack: keep every opened terminal alive.
                        // Opacity controls visibility; allowsHitTesting prevents ghost clicks.
                        ZStack {
                            ForEach(openedProjectIDs, id: \.self) { pid in
                                if let project = projects.first(where: { $0.persistentModelID == pid }) {
                                    ProjectDetailView(project: project)
                                        .opacity(!showDashboard && selectedProject?.persistentModelID == pid ? 1 : 0)
                                        .allowsHitTesting(!showDashboard && selectedProject?.persistentModelID == pid)
                                }
                            }
                        }
                    }
                    // Dashboard sits on top — terminals stay alive underneath.
                    if showDashboard {
                        SessionCardsContainerView()
                    }
                }
                .frame(minWidth: 700, minHeight: 400)
            }
            .frame(minWidth: 750, minHeight: 400)
            .onAppear {
                migrateIfNeeded()
                cleanupAndDeduplicateProjects()
                autoSelectProject()
            }
            .onChange(of: selectedProject) { _, newProject in
                guard let project = newProject else { return }
                let pid = project.persistentModelID
                if !openedProjectIDs.contains(pid) {
                    openedProjectIDs.append(pid)
                }
            }
            .onChange(of: projects) {
                // Remove IDs for deleted projects
                let existing = Set(projects.map { $0.persistentModelID })
                openedProjectIDs = openedProjectIDs.filter { existing.contains($0) }
                autoSelectProject()
            }
        }
    }

    // MARK: - Sidebar

    private var activeSessionCount: Int {
        SessionStore.shared.sessions.values.filter {
            $0.status != .completed && $0.status != .blocked
        }.count
    }

    private var projectSidebar: some View {
        // Manual selection via onTapGesture — List(selection:) with @Model objects
        // conflicts between the explicit `var id: UUID` and SwiftData's generated
        // Identifiable conformance (persistentModelID), causing clicks to be ignored.
        List {
            // Dashboard row — shows cross-project session overview
            HStack(spacing: 6) {
                Label("All Sessions", systemImage: "rectangle.grid.2x2")
                    .lineLimit(1)
                Spacer()
                if activeSessionCount > 0 {
                    Text("\(activeSessionCount)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowBackground(showDashboard ? Color.accentColor.opacity(0.2) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                showDashboard = true
                selectedProject = nil
            }

            ForEach(projects) { project in
                ProjectRow(
                    project: project,
                    isSelected: !showDashboard && selectedProject?.persistentModelID == project.persistentModelID
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    showDashboard = false
                    selectedProject = project
                }
                .contextMenu {
                    Button("Remove", role: .destructive) {
                        if selectedProject?.persistentModelID == project.persistentModelID {
                            selectedProject = nil
                        }
                        modelContext.delete(project)
                        try? modelContext.save()
                    }
                }
            }
        }
        .navigationTitle("Projects")
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: addProject) {
                    Image(systemName: "plus")
                }
                .help("Add Project")
            }
        }
    }

    // MARK: - First Launch Picker

    private var firstLaunchPicker: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "display")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Claude Terminal")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Choose a folder to start working in")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button(action: addProject) {
                Label("Browse…", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding(40)
    }

    // MARK: - Actions

    private func addProject() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Choose Working Directory"
        panel.prompt = "Open"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let selectedPath = url.path
        Task {
            // Use git root as the canonical project identity — so worktrees of
            // the same repo map to one project, not N separate entries.
            let rootPath = await GitStateService.shared.gitRootPath(for: selectedPath) ?? selectedPath
            if let existing = projects.first(where: { $0.path == rootPath }) {
                existing.displayPath = selectedPath
                selectedProject = existing
                return
            }
            let name = (rootPath as NSString).lastPathComponent
            let project = ClaudeProject(name: name, path: rootPath, displayPath: selectedPath)
            project.sortOrder = projects.count
            modelContext.insert(project)
            try? modelContext.save()
            selectedProject = project
        }
    }

    private func autoSelectProject() {
        guard selectedProject == nil, let first = projects.first else { return }
        selectedProject = first
        let pid = first.persistentModelID
        if !openedProjectIDs.contains(pid) {
            openedProjectIDs.append(pid)
        }
    }

    /// Merges duplicate projects that share the same git root, and removes projects
    /// whose paths no longer resolve to any git repository. Runs async — safe to call
    /// on every .onAppear since it's guarded by finding actual duplicates/orphans.
    private func cleanupAndDeduplicateProjects() {
        Task {
            var rootToProject: [String: ClaudeProject] = [:]
            var toDelete: [ClaudeProject] = []

            for project in projects.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                var rootPath = await GitStateService.shared.gitRootPath(for: project.path)
                if rootPath == nil {
                    rootPath = await GitStateService.shared.gitRootPath(for: project.displayPath)
                }
                guard let rootPath else {
                    // Path and its parents are not in any git repo — remove orphan
                    toDelete.append(project)
                    continue
                }

                if let canonical = rootToProject[rootPath] {
                    // Duplicate: keep the canonical (lower sortOrder), merge displayPath if useful
                    if canonical.displayPath == canonical.path {
                        canonical.displayPath = project.displayPath
                    }
                    toDelete.append(project)
                } else {
                    rootToProject[rootPath] = project
                    // Normalise path to git root
                    if project.path != rootPath {
                        project.path = rootPath
                        project.name = (rootPath as NSString).lastPathComponent
                    }
                    // If the last-used directory no longer exists, fall back to git root
                    if !FileManager.default.fileExists(atPath: project.displayPath) {
                        project.displayPath = rootPath
                    }
                }
            }

            guard !toDelete.isEmpty else { return }
            for project in toDelete {
                if selectedProject?.persistentModelID == project.persistentModelID {
                    selectedProject = nil
                }
                modelContext.delete(project)
            }
            try? modelContext.save()
        }
    }

    private func migrateIfNeeded() {
        guard projects.isEmpty else { return }
        var paths: [String] = []
        if !legacyWorkingDirectory.isEmpty {
            paths.append(legacyWorkingDirectory)
        }
        if let data = legacyRecentDirectoriesData.data(using: .utf8),
           let recents = try? JSONDecoder().decode([String].self, from: data) {
            for dir in recents where !paths.contains(dir) {
                paths.append(dir)
            }
        }
        guard !paths.isEmpty else { return }
        Task {
            var seenRoots: Set<String> = []
            var sortOrder = 0
            for path in paths {
                let rootPath = await GitStateService.shared.gitRootPath(for: path) ?? path
                guard !seenRoots.contains(rootPath) else { continue }
                seenRoots.insert(rootPath)
                let name = (rootPath as NSString).lastPathComponent
                let project = ClaudeProject(name: name, path: rootPath, displayPath: path)
                project.sortOrder = sortOrder
                sortOrder += 1
                modelContext.insert(project)
            }
            try? modelContext.save()
        }
    }
}

// MARK: - Project Row

private struct ProjectRow: View {
    let project: ClaudeProject
    var isSelected: Bool = false

    private var activeSessions: [AgentSession] {
        SessionStore.shared.sessions.values.filter { session in
            !session.isSynthetic &&
            session.status != .completed &&
            session.status != .blocked &&
            session.cwd.hasPrefix(project.path)
        }
    }

    private var aggregateStatus: AgentStatus? {
        if activeSessions.contains(where: { $0.status == .awaitingInput }) { return .awaitingInput }
        if activeSessions.contains(where: { $0.status == .running }) { return .running }
        return nil
    }

    var body: some View {
        HStack(spacing: 6) {
            Label(project.name, systemImage: "folder")
                .lineLimit(1)
            Spacer()
            if let status = aggregateStatus {
                HStack(spacing: 4) {
                    if activeSessions.count > 1 {
                        Text("\(activeSessions.count)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                    Circle()
                        .fill(status == .awaitingInput ? Color.orange : Color.green)
                        .frame(width: 7, height: 7)
                }
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowBackground(
            isSelected ? Color.accentColor.opacity(0.2) : Color.clear
        )
    }
}

#Preview {
    MainView()
        .frame(width: 900, height: 600)
}
