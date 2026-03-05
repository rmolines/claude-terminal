import SwiftUI
import AppKit
import SwiftData

/// Root view: sidebar of ClaudeProject entities + terminal detail for the selected project.
///
/// On first launch (no projects, no legacy directory), shows a directory picker.
/// On subsequent launches, auto-selects the first project.
/// Legacy @AppStorage data is migrated to SwiftData on first run.
struct MainView: View {
    @Query(sort: \ClaudeProject.sortOrder) var projects: [ClaudeProject]
    @Environment(\.modelContext) var modelContext
    @State private var selectedProject: ClaudeProject?

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
                if let project = selectedProject {
                    // .id forces full recreation (including @State sessionID) when
                    // the selected project changes — so the PTY restarts in the new directory.
                    ProjectDetailView(project: project)
                        .id(project.id)
                } else {
                    ContentUnavailableView("Select a Project", systemImage: "folder")
                        .frame(minWidth: 700, minHeight: 400)
                }
            }
            .frame(minWidth: 750, minHeight: 400)
            .onAppear {
                migrateIfNeeded()
                autoSelectProject()
            }
            .onChange(of: projects) {
                autoSelectProject()
            }
        }
    }

    // MARK: - Sidebar

    private var projectSidebar: some View {
        // Manual selection via onTapGesture — List(selection:) with @Model objects
        // conflicts between the explicit `var id: UUID` and SwiftData's generated
        // Identifiable conformance (persistentModelID), causing clicks to be ignored.
        List {
            ForEach(projects) { project in
                ProjectRow(
                    project: project,
                    isSelected: selectedProject?.persistentModelID == project.persistentModelID
                )
                .contentShape(Rectangle())
                .onTapGesture { selectedProject = project }
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
        guard selectedProject == nil else { return }
        selectedProject = projects.first
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

    var body: some View {
        Label(project.name, systemImage: "folder")
            .lineLimit(1)
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
