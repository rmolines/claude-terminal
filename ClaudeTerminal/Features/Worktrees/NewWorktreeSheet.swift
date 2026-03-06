import SwiftUI

/// Sheet para criar um novo worktree via git.
/// Valida nome (kebab-case), cria o branch `feature/<name>` e
/// opcionalmente injeta `/start-feature <name>` no terminal após abertura.
struct NewWorktreeSheet: View {
    let rootPath: String
    let onCreated: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var injectStartFeature: Bool = true
    @State private var isCreating: Bool = false
    @State private var errorMessage: String? = nil

    private var isValid: Bool {
        name.range(of: "^[a-z][a-z0-9-]{0,48}$", options: .regularExpression) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Worktree")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                TextField("feature-name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: name) { _, new in
                        let coerced = new.lowercased().replacingOccurrences(of: "_", with: "-")
                        if coerced != new { name = coerced }
                        errorMessage = nil
                    }

                if !name.isEmpty && !isValid {
                    Text("Lowercase letters, numbers and hyphens only (e.g. my-feature)")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text(name.isEmpty ? "Branch: feature/..." : "Branch: feature/\(name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle("Inject /start-feature after open", isOn: $injectStartFeature)
                .toggleStyle(.checkbox)

            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create") {
                    Task { await createWorktree() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid || isCreating)
            }
        }
        .padding(20)
        .frame(width: 320)
        .disabled(isCreating)
    }

    private func createWorktree() async {
        isCreating = true
        defer { isCreating = false }
        do {
            let path = try await GitStateService.shared.addWorktree(name: name, in: rootPath)
            let input = injectStartFeature ? "/start-feature \(name)" : ""
            dismiss()
            onCreated(path, input)
        } catch {
            errorMessage = "Failed to create worktree: \(error.localizedDescription)"
        }
    }
}
