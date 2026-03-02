import SwiftUI
import SwiftData
import AppKit

/// Persistent backlog of features, fixes, and projects.
struct TaskBacklogView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ClaudeTask.sortOrder) private var tasks: [ClaudeTask]

    @State private var isAddingTask = false
    @State private var newTaskTitle = ""
    @State private var newTaskType = "feature"

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(tasks) { task in
                    TaskRow(task: task)
                }
                .onDelete(perform: deleteTasks)
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
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(isAddingTask)
            }
        }
    }

    // MARK: - New task form

    private var newTaskForm: some View {
        VStack(alignment: .leading, spacing: 6) {
            // AutoFocusTextField bypasses SwiftUI @FocusState limitations inside
            // NavigationSplitView sidebar — calls makeFirstResponder at AppKit level.
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
        let task = ClaudeTask(title: title, taskType: newTaskType)
        task.sortOrder = nextOrder
        task.status = "pending"
        context.insert(task)
        try? context.save()

        isAddingTask = false
        newTaskTitle = ""
    }

    private func deleteTasks(at offsets: IndexSet) {
        for index in offsets {
            context.delete(tasks[index])
        }
        try? context.save()
    }
}

// MARK: - Previews

@MainActor
private func previewContainer() -> ModelContainer {
    let container = try! ModelContainer(
        for: ClaudeTask.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let samples: [(String, String, String)] = [
        ("Implement auth flow", "feature", "pending"),
        ("Fix crash on app launch", "fix", "running"),
        ("Migrate to SwiftData v2", "project", "completed"),
        ("Add dark mode support", "feature", "pending"),
    ]
    for (i, (title, type, status)) in samples.enumerated() {
        let task = ClaudeTask(title: title, taskType: type)
        task.sortOrder = i
        task.status = status
        container.mainContext.insert(task)
    }
    return container
}

#Preview("Backlog — with tasks") {
    NavigationStack {
        TaskBacklogView()
    }
    .modelContainer(previewContainer())
    .frame(width: 280, height: 400)
}

#Preview("Backlog — empty") {
    NavigationStack {
        TaskBacklogView()
    }
    .modelContainer(
        try! ModelContainer(
            for: ClaudeTask.self,
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
