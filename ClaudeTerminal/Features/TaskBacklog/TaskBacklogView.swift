import SwiftUI
import SwiftData

/// Persistent backlog of features, fixes, and projects.
struct TaskBacklogView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ClaudeTask.sortOrder) private var tasks: [ClaudeTask]

    @State private var isAddingTask = false
    @State private var newTaskTitle = ""
    @State private var newTaskType = "feature"

    var body: some View {
        List {
            ForEach(tasks) { task in
                TaskRow(task: task)
            }
            .onDelete(perform: deleteTasks)

            if isAddingTask {
                newTaskRow
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

    // MARK: - New task inline row

    private var newTaskRow: some View {
        HStack(spacing: 8) {
            Picker("", selection: $newTaskType) {
                Text("feat").tag("feature")
                Text("fix").tag("fix")
                Text("proj").tag("project")
            }
            .labelsHidden()
            .frame(width: 60)

            TextField("Task title…", text: $newTaskTitle)
                .onSubmit { commitNewTask() }

            Button("Add", action: commitNewTask)
                .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)

            Button("Cancel") {
                isAddingTask = false
                newTaskTitle = ""
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
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
