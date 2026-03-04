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
                    ProjectDetailView(project: project)
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
        List(projects, selection: $selectedProject) { project in
            ProjectRow(project: project)
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
        .contextMenu(forSelectionType: ClaudeProject.self) { items in
            Button("Remove", role: .destructive) {
                for item in items { modelContext.delete(item) }
                try? modelContext.save()
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
        let path = url.path
        if let existing = projects.first(where: { $0.path == path || $0.displayPath == path }) {
            selectedProject = existing
            return
        }
        let name = url.lastPathComponent
        let project = ClaudeProject(name: name, path: path, displayPath: path)
        project.sortOrder = projects.count
        modelContext.insert(project)
        try? modelContext.save()
        selectedProject = project
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
        for (index, path) in paths.enumerated() {
            let name = (path as NSString).lastPathComponent
            let project = ClaudeProject(name: name, path: path, displayPath: path)
            project.sortOrder = index
            modelContext.insert(project)
        }
        if !paths.isEmpty {
            try? modelContext.save()
        }
    }
}

// MARK: - Project Row

private struct ProjectRow: View {
    let project: ClaudeProject

    var body: some View {
        Label(project.name, systemImage: "folder")
            .lineLimit(1)
    }
}

#Preview {
    MainView()
        .frame(width: 900, height: 600)
}
