import SwiftUI

/// A single pending HITL item in the approval queue.
struct HITLItem {
    let sessionID: String
    let description: String
    let toolName: String?
    let riskLevel: RiskLevel
    let onApprove: () -> Void
    let onReject: () -> Void
}

/// Card for one HITL approval request: tool badge, description, risk indicator, approve/reject.
struct ApprovalCardView: View {
    let item: HITLItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            Text(item.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            actionRow
        }
        .padding(12)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(riskBorderColor, lineWidth: 1)
        )
    }

    // MARK: - Sub-views

    private var headerRow: some View {
        HStack(spacing: 6) {
            riskIndicator
            if let tool = item.toolName {
                Text(tool)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.semibold)
            }
            Spacer()
            Text("…\(String(item.sessionID.suffix(6)))")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }

    private var riskIndicator: some View {
        Group {
            switch item.riskLevel {
            case .critical:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            case .elevated:
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.caption)
            case .normal:
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }

    private var actionRow: some View {
        HStack {
            Button("Reject", role: .destructive) { item.onReject() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Spacer()
            Button("Approve") { item.onApprove() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }

    private var riskBorderColor: Color {
        switch item.riskLevel {
        case .critical: return .red.opacity(0.4)
        case .elevated: return .orange.opacity(0.3)
        case .normal: return Color(.separatorColor)
        }
    }
}

#Preview("Normal risk") {
    ApprovalCardView(item: HITLItem(
        sessionID: "abcdef-123456",
        description: "Read file: /Users/me/repo/Package.swift",
        toolName: "Read",
        riskLevel: .normal,
        onApprove: {},
        onReject: {}
    ))
    .frame(width: 400)
    .padding()
}

#Preview("Critical risk") {
    ApprovalCardView(item: HITLItem(
        sessionID: "abcdef-789012",
        description: "rm -rf .build && swift build -c release",
        toolName: "Bash",
        riskLevel: .critical,
        onApprove: {},
        onReject: {}
    ))
    .frame(width: 400)
    .padding()
}
