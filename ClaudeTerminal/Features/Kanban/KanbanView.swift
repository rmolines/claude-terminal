import SwiftUI

struct KanbanView: View {
    let projectPath: String

    @State private var backlog: KanbanBacklogFile?

    var body: some View {
        Group {
            if let backlog, !backlog.milestones.isEmpty || !backlog.features.isEmpty {
                kanbanBoard(backlog: backlog)
            } else if backlog != nil {
                emptyState(message: "Sem features no backlog.json")
            } else {
                emptyState(message: "backlog.json não encontrado neste projeto")
            }
        }
        .task {
            await loadAndPoll()
        }
    }

    // MARK: - Board layout

    private func kanbanBoard(backlog: KanbanBacklogFile) -> some View {
        ScrollView {
            HStack(alignment: .top, spacing: 16) {
                ForEach(KanbanStatus.allCases, id: \.rawValue) { status in
                    KanbanColumn(
                        status: status,
                        features: backlog.features.filter { $0.status == status },
                        milestones: backlog.milestones
                    )
                }
            }
            .padding(16)
        }
    }

    // MARK: - Empty state

    private func emptyState(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "square.3.layers.3d.slash")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Poll loop

    private func loadAndPoll() async {
        backlog = KanbanReader.shared.load(projectPath: projectPath)
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            backlog = KanbanReader.shared.load(projectPath: projectPath)
        }
    }
}

// MARK: - Column

private struct KanbanColumn: View {
    let status: KanbanStatus
    let features: [KanbanFeature]
    let milestones: [KanbanMilestone]

    /// Features grouped by milestone id, in milestone order.
    private var grouped: [(milestone: KanbanMilestone?, features: [KanbanFeature])] {
        // Collect milestone IDs that appear in this column, preserving milestone order.
        var seen = Set<String>()
        var orderedIds: [String] = []
        for m in milestones where features.contains(where: { $0.milestone == m.id }) {
            if seen.insert(m.id).inserted { orderedIds.append(m.id) }
        }
        // Features with unknown milestone id go last.
        let unknownFeatures = features.filter { f in !milestones.contains(where: { $0.id == f.milestone }) }

        var result: [(KanbanMilestone?, [KanbanFeature])] = orderedIds.compactMap { id in
            guard let m = milestones.first(where: { $0.id == id }) else { return nil }
            let fs = features
                .filter { $0.milestone == id }
                .sorted { lhs, rhs in
                    if let l = lhs.sortOrder, let r = rhs.sortOrder { return l < r }
                    return (lhs.createdAt ?? "") < (rhs.createdAt ?? "")
                }
            return (m, fs)
        }
        if !unknownFeatures.isEmpty { result.append((nil, unknownFeatures)) }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            columnHeader
            Divider().padding(.bottom, 8)

            if features.isEmpty {
                Text("Vazio")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(grouped.enumerated()), id: \.offset) { _, group in
                            milestoneSection(milestone: group.milestone, features: group.features)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 220, maxWidth: 300, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var columnHeader: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(headerColor)
                .frame(width: 8, height: 8)
            Text(status.columnTitle)
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            Text("\(features.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }

    private var headerColor: Color {
        switch status {
        case .pending:    return .secondary
        case .inProgress: return .green
        case .done:       return .blue
        }
    }

    private func milestoneSection(milestone: KanbanMilestone?, features: [KanbanFeature]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(milestone?.name ?? "Sem milestone")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.top, 4)
            ForEach(features) { feature in
                KanbanCard(feature: feature)
            }
        }
    }
}

// MARK: - Card

private struct KanbanCard: View {
    let feature: KanbanFeature

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(feature.title)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if !feature.labels.isEmpty {
                labelsRow
            }

            if let pr = feature.prNumber {
                Text("PR #\(pr)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }

    private var labelsRow: some View {
        FlowLayout(spacing: 4) {
            ForEach(feature.labels, id: \.self) { label in
                Text(label)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - FlowLayout (wrapping HStack for labels)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(subviews: subviews, in: proposal.replacingUnspecifiedDimensions())
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, in: bounds.size)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                                  proposal: ProposedViewSize(frame.size))
        }
    }

    private struct LayoutResult {
        var size: CGSize
        var frames: [CGRect]
    }

    private func layout(subviews: Subviews, in containerSize: CGSize) -> LayoutResult {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > containerSize.width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return LayoutResult(
            size: CGSize(width: containerSize.width, height: y + rowHeight),
            frames: frames
        )
    }
}

#Preview {
    KanbanView(projectPath: "/Users/rmolines/git/claude-terminal")
        .frame(width: 800, height: 600)
}
