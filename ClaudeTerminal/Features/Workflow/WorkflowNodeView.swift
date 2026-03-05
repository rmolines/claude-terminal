import SwiftUI

/// Visual representation of a single workflow node (80×44pt).
struct WorkflowNodeView: View {
    let node: WorkflowNode
    let state: RenderedNodeState

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: node.icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(iconColor)
            Text(node.label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(labelColor)
                .lineLimit(1)
            if state == .done {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 8)
        .frame(width: 130, height: 36)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(borderColor, lineWidth: borderWidth)
        )
    }

    // MARK: - Appearance

    private var background: some ShapeStyle {
        switch state {
        case .notStarted:
            return AnyShapeStyle(Color.clear)
        case .activeOrAwaiting:
            return AnyShapeStyle(Color.accentColor.opacity(0.15))
        case .done:
            return AnyShapeStyle(Color.primary.opacity(0.07))
        case .anomaly:
            return AnyShapeStyle(Color.clear)
        }
    }

    private var borderColor: Color {
        switch state {
        case .notStarted:      return .secondary.opacity(0.35)
        case .activeOrAwaiting: return .accentColor
        case .done:            return .secondary.opacity(0.2)
        case .anomaly:         return .orange
        }
    }

    private var borderWidth: CGFloat {
        state == .activeOrAwaiting ? 1.5 : 1
    }

    private var iconColor: Color {
        switch state {
        case .notStarted:      return .secondary.opacity(0.5)
        case .activeOrAwaiting: return .accentColor
        case .done:            return .secondary
        case .anomaly:         return .orange
        }
    }

    private var labelColor: Color {
        switch state {
        case .notStarted:      return .secondary.opacity(0.6)
        case .activeOrAwaiting: return .primary
        case .done:            return .secondary
        case .anomaly:         return .orange
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        WorkflowNodeView(
            node: WorkflowNode(id: "/start-feature", icon: "plus.square", label: "start-feature", x: 0, y: 0),
            state: .notStarted
        )
        WorkflowNodeView(
            node: WorkflowNode(id: "/start-feature", icon: "plus.square", label: "start-feature", x: 0, y: 0),
            state: .activeOrAwaiting
        )
        WorkflowNodeView(
            node: WorkflowNode(id: "/start-feature", icon: "plus.square", label: "start-feature", x: 0, y: 0),
            state: .done
        )
        WorkflowNodeView(
            node: WorkflowNode(id: "/start-feature", icon: "plus.square", label: "start-feature", x: 0, y: 0),
            state: .anomaly
        )
    }
    .padding()
}
