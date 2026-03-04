import SwiftUI
import Shared

/// Card por agente mostrando o estado atual e as skills recomendadas para o próximo passo.
struct AgentWorkflowCard: View {
    let session: AgentSession
    let branch: String

    @State private var showAllSkills = false

    private var phase: WorkflowPhase {
        WorkflowPhase.infer(branch: branch, cwd: session.cwd)
    }

    private var nextSteps: [SkillDefinition] {
        Array(SkillDefinition.nextSteps(for: phase).prefix(3))
    }

    private var allSkills: [SkillDefinition] {
        SkillDefinition.skills(for: phase)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            nextStepsSection
            if !allSkills.isEmpty {
                Divider()
                allSkillsSection
            }
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator, lineWidth: 1)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(abbreviatedID)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    statusBadge
                    if branch != "—" {
                        Text(branch)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            Spacer()
            phasePill
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var abbreviatedID: String {
        let id = session.sessionID
        return id.count > 12 ? "…" + String(id.suffix(8)) : id
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(session.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
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
        case .featureActive: return "Feature Active"
        case .readyToShip: return "Ready to Ship"
        case .unknown: return "Unknown"
        }
    }

    private var phaseColor: Color {
        switch phase {
        case .strategic: return .blue
        case .featureActive: return .purple
        case .readyToShip: return .green
        case .unknown: return .gray
        }
    }

    // MARK: - Next steps

    private var nextStepsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Próximos passos")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)

            if nextSteps.isEmpty {
                Text("Nenhuma skill recomendada para este estado.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            } else {
                ForEach(nextSteps) { skill in
                    SkillRow(skill: skill)
                }
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - All skills

    private var allSkillsSection: some View {
        DisclosureGroup(
            isExpanded: $showAllSkills,
            content: {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(allSkills) { skill in
                        SkillRow(skill: skill, compact: true)
                    }
                }
                .padding(.bottom, 8)
            },
            label: {
                Text("Todas as skills desta fase (\(allSkills.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - SkillRow

private struct SkillRow: View {
    let skill: SkillDefinition
    var compact: Bool = false

    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: skill.icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(skill.id)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                if !compact {
                    Text(skill.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(skill.id, forType: .string)
                withAnimation { copied = true }
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    withAnimation { copied = false }
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.caption2)
                    .foregroundStyle(copied ? .green : .secondary)
            }
            .buttonStyle(.borderless)
            .help("Copiar \(skill.id)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, compact ? 3 : 6)
        .contentShape(Rectangle())
    }
}
