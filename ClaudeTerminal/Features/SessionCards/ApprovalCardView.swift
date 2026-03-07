import SwiftUI

// MARK: - Tool badge

/// Colored badge with SF Symbol icon for a Claude Code tool name.
private struct ToolBadge: View {
    let toolName: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(toolName)
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.semibold)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }

    private var icon: String {
        switch toolName {
        case "Bash":                          return "terminal"
        case "Write":                         return "square.and.arrow.down"
        case "Edit", "MultiEdit":             return "square.and.pencil"
        case "Read", "Glob", "Grep":          return "magnifyingglass"
        case "WebFetch", "WebSearch":         return "globe"
        case "TodoWrite", "TodoRead":         return "checklist"
        default:                              return "wrench.and.screwdriver"
        }
    }

    private var tint: Color {
        switch toolName {
        case "Bash":                          return .red
        case "Write", "Edit", "MultiEdit":   return .blue
        case "Read", "Glob", "Grep":         return .secondary
        case "WebFetch", "WebSearch":         return .teal
        default:                              return .secondary
        }
    }
}

// MARK: - HITL item

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
                ToolBadge(toolName: tool)
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

#Preview("Critical risk — Bash") {
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

#Preview("Write file") {
    ApprovalCardView(item: HITLItem(
        sessionID: "abcdef-345678",
        description: "/Users/me/repo/ClaudeTerminal/Features/SessionCards/ApprovalCardView.swift",
        toolName: "Write",
        riskLevel: .normal,
        onApprove: {},
        onReject: {}
    ))
    .frame(width: 400)
    .padding()
}

#Preview("All tool badges") {
    VStack(spacing: 8) {
        ForEach(["Bash", "Write", "Edit", "Read", "Glob", "WebFetch", "TodoWrite", "Mcp"], id: \.self) { tool in
            ApprovalCardView(item: HITLItem(
                sessionID: "preview-000001",
                description: "Example operation for \(tool)",
                toolName: tool,
                riskLevel: .normal,
                onApprove: {},
                onReject: {}
            ))
        }
    }
    .frame(width: 400)
    .padding()
}
