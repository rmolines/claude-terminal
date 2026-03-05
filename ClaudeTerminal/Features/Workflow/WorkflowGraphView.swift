import SwiftUI

/// Canvas with Bezier edges + ZStack of WorkflowNodeViews.
/// Reads `project.workflowStates` reactively via @Bindable.
struct WorkflowGraphView: View {
    @Bindable var project: ClaudeProject

    private let nodeWidth: CGFloat = 130
    private let nodeHeight: CGFloat = 36

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Edges drawn on a Canvas below the nodes
                Canvas { context, size in
                    drawEdges(context: context, size: size)
                }
                .frame(width: w, height: h)

                // Nodes as SwiftUI views
                ForEach(WorkflowGraphLayout.nodes) { node in
                    WorkflowNodeView(node: node, state: effectiveState(for: node.id))
                        .position(
                            x: node.x * w,
                            y: node.y * h
                        )
                }
            }
        }
        .padding(16)
        .task(id: project.path) {
            while !Task.isCancelled {
                await WorkflowUpdateService.shared.syncFromDisk(project: project)
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s
            }
        }
    }

    // MARK: - State computation

    private func effectiveState(for nodeID: String) -> RenderedNodeState {
        let states = project.workflowStates
        let persisted = states[nodeID] ?? .notStarted
        switch persisted {
        case .notStarted:
            return .notStarted
        case .activeOrAwaiting:
            return .activeOrAwaiting
        case .done:
            // Check for anomaly: done but a prerequisite is not done
            let prereqs = WorkflowGraphLayout.prerequisites(of: nodeID)
            let hasUndonePrereq = prereqs.contains { prereqID in
                (states[prereqID] ?? .notStarted) != .done
            }
            return hasUndonePrereq ? .anomaly : .done
        }
    }

    // MARK: - Edge drawing

    private func drawEdges(context: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height

        for edge in WorkflowGraphLayout.edges {
            guard let fromNode = WorkflowGraphLayout.node(for: edge.from),
                  let toNode = WorkflowGraphLayout.node(for: edge.to) else { continue }

            let fromPoint = CGPoint(
                x: fromNode.x * w,
                y: fromNode.y * h + nodeHeight / 2
            )
            let toPoint = CGPoint(
                x: toNode.x * w,
                y: toNode.y * h - nodeHeight / 2
            )

            let path = bezierPath(from: fromPoint, to: toPoint)
            let color: Color = edge.isCanonical
                ? .secondary.opacity(0.4)
                : .secondary.opacity(0.2)

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(
                    lineWidth: edge.isCanonical ? 1.5 : 1,
                    dash: edge.isCanonical ? [] : [4, 3]
                )
            )

            drawArrowhead(context: context, at: toPoint, color: color)
        }
    }

    private func bezierPath(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        path.move(to: start)
        let controlOffset = (end.y - start.y) * 0.5
        path.addCurve(
            to: end,
            control1: CGPoint(x: start.x, y: start.y + controlOffset),
            control2: CGPoint(x: end.x, y: end.y - controlOffset)
        )
        return path
    }

    private func drawArrowhead(context: GraphicsContext, at tip: CGPoint, color: Color) {
        let size: CGFloat = 5
        var arrow = Path()
        arrow.move(to: CGPoint(x: tip.x, y: tip.y))
        arrow.addLine(to: CGPoint(x: tip.x - size * 0.6, y: tip.y - size))
        arrow.addLine(to: CGPoint(x: tip.x + size * 0.6, y: tip.y - size))
        arrow.closeSubpath()
        context.fill(arrow, with: .color(color))
    }
}
