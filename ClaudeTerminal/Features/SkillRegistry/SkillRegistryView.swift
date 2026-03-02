import SwiftUI

struct SkillRegistryView: View {
    let projectCwds: [String]

    @State private var entries: [SkillEntry] = []
    @State private var query: String = ""
    @Environment(\.dismiss) private var dismiss

    private var filtered: [SkillEntry] {
        guard !query.isEmpty else { return entries }
        return entries.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.description.localizedCaseInsensitiveContains(query)
        }
    }

    private func entries(for kind: SkillKind) -> [SkillEntry] {
        filtered.filter { $0.kind == kind }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Skills Registry")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search by name or description…", text: $query)
                    .textFieldStyle(.plain)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(.background.secondary)

            Divider()

            if entries.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filtered.isEmpty {
                Text("No skills match \"\(query)\"")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(SkillKind.allCases, id: \.self) { kind in
                        let kindEntries = entries(for: kind)
                        if !kindEntries.isEmpty {
                            Section(kind.rawValue) {
                                ForEach(kindEntries) { entry in
                                    SkillRow(entry: entry)
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 520, minHeight: 420)
        .task {
            entries = await loadSkills(projectCwds: projectCwds)
        }
    }
}

// MARK: - SkillRow

private struct SkillRow: View {
    let entry: SkillEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.name)
                    .font(.body.bold())
                Spacer()
                kindBadge
            }
            if !entry.description.isEmpty {
                Text(entry.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private var kindBadge: some View {
        Text(entry.kind.rawValue)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(kindColor.opacity(0.15))
            .foregroundStyle(kindColor)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var kindColor: Color {
        switch entry.kind {
        case .autoTrigger:    .purple
        case .globalCommand:  .blue
        case .projectCommand: .green
        }
    }
}
