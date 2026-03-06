import SwiftUI
import Shared

/// Header row for a session card: status badge, project name, branch, phase pill, elapsed time.
struct SessionCardHeaderView: View {
    let session: AgentSession
    let projectName: String
    let now: Date

    private var phase: WorkflowPhase {
        WorkflowPhase.infer(branch: session.branch ?? "", cwd: session.cwd)
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    statusBadge
                    Text(projectName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    if let branch = session.branch {
                        Text(branch)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Text(elapsedString)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
            Spacer()
            phasePill
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Sub-views

    private var statusBadge: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 7, height: 7)
    }

    private var statusColor: Color {
        switch session.status {
        case .running: return .green
        case .awaitingInput: return .orange
        case .blocked: return .red
        case .completed: return .gray
        }
    }

    private var phasePill: some View {
        Text(phaseLabel)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(phaseColor.opacity(0.15))
            .foregroundStyle(phaseColor)
            .clipShape(Capsule())
    }

    private var phaseLabel: String {
        switch phase {
        case .strategic: return "Strategic"
        case .featureActive: return "Feature"
        case .readyToShip: return "Ready"
        case .unknown: return "—"
        }
    }

    private var phaseColor: Color {
        switch phase {
        case .strategic: return .blue
        case .featureActive: return .purple
        case .readyToShip: return .green
        case .unknown: return .secondary
        }
    }

    private var elapsedString: String {
        let secs = Int(now.timeIntervalSince(session.startedAt))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
