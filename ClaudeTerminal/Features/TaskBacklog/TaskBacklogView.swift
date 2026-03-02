import SwiftUI
import SwiftData
import AppKit

// MARK: - TaskGroup helper

private struct TaskGroup: Identifiable {
    static let othersID = "other"

    let id: String         // project.id.uuidString or TaskGroup.othersID
    let title: String
    let projectPath: String?
    var tasks: [ClaudeTask]

    /// Path to display in section header — nil when last path component matches title (no redundancy).
    var displayPath: String? {
        guard let path = projectPath else { return nil }
        return URL(fileURLWithPath: path).lastPathComponent == title ? nil : path
    }
}

// MARK: - TaskBacklogView

/// Persistent backlog of features, fixes, and projects — grouped by repo, sorted by priority.
struct TaskBacklogView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ClaudeProject.sortOrder) private var projects: [ClaudeProject]
    @Query(sort: \ClaudeTask.sortOrder) private var tasks: [ClaudeTask]

    @State private var isAddingTask = false
    @State private var newTaskTitle = ""
    @State private var newTaskType = "feature"
    @State private var newTaskPriority = "medium"
    @State private var newTaskProject: ClaudeProject?

    // MARK: Computed grouping

    private var groupedTasks: [TaskGroup] {
        // Single O(N) pass: bucket tasks by project UUID (nil = "other")
        let byProject = Dictionary(grouping: tasks, by: { $0.project?.id })
        let sortedByPriority = { (taskList: [ClaudeTask]) in
            taskList.sorted { $0.prioritySortKey < $1.prioritySortKey }
        }

        var groups: [TaskGroup] = projects.compactMap { project in
            guard let projectTasks = byProject[project.id], !projectTasks.isEmpty else { return nil }
            return TaskGroup(
                id: project.id.uuidString,
                title: project.name,
                projectPath: project.path,
                tasks: sortedByPriority(projectTasks)
            )
        }

        // "Other" section for tasks not assigned to any project
        if let ungrouped = byProject[nil], !ungrouped.isEmpty {
            groups.append(TaskGroup(
                id: TaskGroup.othersID,
                title: "Other",
                projectPath: nil,
                tasks: sortedByPriority(ungrouped)
            ))
        }

        return groups
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                if groupedTasks.isEmpty {
                    emptyPlaceholder
                } else {
                    ForEach(groupedTasks) { group in
                        Section(header: sectionHeader(group)) {
                            ForEach(group.tasks) { task in
                                TaskRow(task: task)
                            }
                            .onDelete { offsets in
                                deleteTasks(group.tasks, at: offsets)
                            }
                        }
                    }
                }
            }

            if isAddingTask {
                Divider()
                newTaskForm
                    .padding(12)
            }
        }
        .navigationTitle("Backlog")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingTask = true
                    newTaskTitle = ""
                    newTaskType = "feature"
                    newTaskPriority = "medium"
                    newTaskProject = nil
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(isAddingTask)
            }
        }
    }

    // MARK: - Section header

    @ViewBuilder
    private func sectionHeader(_ group: TaskGroup) -> some View {
        HStack(spacing: 4) {
            if group.id != TaskGroup.othersID {
                Image(systemName: "folder.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(group.title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if let path = group.displayPath {
                Text(path)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
        .textCase(nil)
    }

    // MARK: - Empty placeholder

    private var emptyPlaceholder: some View {
        Text("No tasks yet — tap + to add one")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
            .listRowBackground(Color.clear)
    }

    // MARK: - New task form

    private var newTaskForm: some View {
        VStack(alignment: .leading, spacing: 6) {
            AutoFocusTextField(
                text: $newTaskTitle,
                placeholder: "Task title…",
                onSubmit: commitNewTask
            )
            .frame(height: 22)

            HStack(spacing: 6) {
                Picker("", selection: $newTaskType) {
                    Text("feat").tag("feature")
                    Text("fix").tag("fix")
                    Text("proj").tag("project")
                }
                .labelsHidden()
                .frame(width: 72)

                Picker("", selection: $newTaskPriority) {
                    Text("P0").tag("urgent")
                    Text("P1").tag("high")
                    Text("P2").tag("medium")
                    Text("P3").tag("low")
                }
                .labelsHidden()
                .frame(width: 52)

                if !projects.isEmpty {
                    Picker("", selection: $newTaskProject) {
                        Text("No project").tag(Optional<ClaudeProject>.none)
                        ForEach(projects) { project in
                            Text(project.name).tag(Optional(project))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 110)
                }

                Spacer()

                Button("Cancel") {
                    isAddingTask = false
                    newTaskTitle = ""
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button("Add", action: commitNewTask)
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Mutations

    private func commitNewTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }

        let nextOrder = (tasks.map(\.sortOrder).max() ?? -1) + 1
        let task = ClaudeTask(title: title, taskType: newTaskType, priority: newTaskPriority)
        task.sortOrder = nextOrder
        task.status = "pending"
        task.project = newTaskProject
        context.insert(task)
        try? context.save()

        isAddingTask = false
        newTaskTitle = ""
    }

    private func deleteTasks(_ groupTasks: [ClaudeTask], at offsets: IndexSet) {
        for index in offsets {
            context.delete(groupTasks[index])
        }
        try? context.save()
    }
}

// MARK: - Previews

@MainActor
private func previewContainer() -> ModelContainer {
    let container = try! ModelContainer(
        for: ClaudeTask.self, ClaudeAgent.self, ClaudeProject.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let proj = ClaudeProject(name: "claude-terminal", path: "/Users/dev/git/claude-terminal")
    proj.sortOrder = 0
    container.mainContext.insert(proj)

    let samples: [(String, String, String, String, Bool)] = [
        ("Implement auth flow", "feature", "pending", "urgent", true),
        ("Fix crash on app launch", "fix", "running", "high", true),
        ("Migrate to SwiftData v2", "project", "completed", "medium", false),
        ("Add dark mode support", "feature", "pending", "low", false),
    ]
    for (i, (title, type, status, priority, inProject)) in samples.enumerated() {
        let task = ClaudeTask(title: title, taskType: type, priority: priority)
        task.sortOrder = i
        task.status = status
        task.project = inProject ? proj : nil
        container.mainContext.insert(task)
    }
    return container
}

#Preview("Backlog — with tasks") {
    NavigationStack {
        TaskBacklogView()
    }
    .modelContainer(previewContainer())
    .frame(width: 280, height: 500)
}

#Preview("Backlog — empty") {
    NavigationStack {
        TaskBacklogView()
    }
    .modelContainer(
        try! ModelContainer(
            for: ClaudeTask.self, ClaudeAgent.self, ClaudeProject.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    )
    .frame(width: 280, height: 400)
}

// MARK: - AutoFocusTextField

/// NSTextField wrapper that grabs AppKit first responder on appear.
///
/// SwiftUI's @FocusState only controls the visual focus ring — it does not
/// change the AppKit first responder when NavigationSplitView sidebar holds it.
/// This view calls makeFirstResponder directly after a short delay.
private struct AutoFocusTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.bezelStyle = .roundedBezel
        field.focusRingType = .default
        field.delegate = context.coordinator

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak field] in
            guard let field, let window = field.window else { return }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: AutoFocusTextField

        init(parent: AutoFocusTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}

// MARK: - TaskRow

private struct TaskRow: View {
    let task: ClaudeTask

    var body: some View {
        HStack(spacing: 8) {
            statusDot
            Text(task.title)
                .lineLimit(1)
            Spacer()
            priorityBadge
            taskTypeBadge
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var statusDot: some View {
        switch task.status {
        case "running":
            Image(systemName: "circle.fill").foregroundStyle(.green)
        case "awaiting_input":
            Image(systemName: "circle.fill").foregroundStyle(.orange)
        case "completed":
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.secondary)
        case "blocked":
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        default: // "pending"
            Image(systemName: "circle").foregroundStyle(.secondary)
        }
    }

    private var priorityBadge: some View {
        let (label, color) = task.priorityDisplay
        return Text(label)
            .font(.caption.bold())
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var taskTypeBadge: some View {
        let label: String
        switch task.taskType {
        case "feature": label = "feat"
        case "fix":     label = "fix"
        default:        label = "proj"
        }
        return Text(label)
            .font(.caption.bold())
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(.gray.opacity(0.15))
            .foregroundStyle(.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
