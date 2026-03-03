import SwiftUI
import Shared

/// A fixed-size card representing one active agent session.
///
/// Shows status, working directory, last hook event as session context,
/// elapsed time, and token cost. When the agent is awaiting HITL approval,
/// the bottom row becomes interactive (Approve / Reject buttons).
/// Tapping the card opens the raw terminal in a popover.
struct AgentCardView: View {
    let session: AgentSession
    @State private var showTerminal = false
    @State private var replyText = ""

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            VStack(alignment: .leading, spacing: 0) {
                topRow
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .onTapGesture { showTerminal = true }

                bottomRow
                    .padding(.horizontal, 12)
                    .padding(.top, 4)

                if !session.recentMessages.isEmpty {
                    Divider().padding(.top, 6)
                    messagesPreview
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                }

                if session.status == .running || session.status == .awaitingInput {
                    Divider().padding(.top, 6)
                    replyBox
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                } else {
                    Spacer().frame(height: 10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
        }
        .popover(isPresented: $showTerminal) {
            AgentTerminalView(session: session)
                .frame(width: 720, height: 440)
        }
    }

    // MARK: - Top row: status dot + cwd + timer

    private var topRow: some View {
        HStack(spacing: 8) {
            statusDot
            Text(session.cwd)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text(formatElapsed(session.startedAt))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - Bottom row: context line (or HITL controls) + badges

    @ViewBuilder
    private var bottomRow: some View {
        if session.status == .awaitingInput {
            hitlControls
        } else {
            HStack(spacing: 6) {
                activityText
                    .onTapGesture { showTerminal = true }
                Spacer()
                subAgentBadge
                tokenBadge
            }
        }
    }

    private var activityText: some View {
        Text(session.currentActivity ?? session.sessionID)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var hitlControls: some View {
        HStack(spacing: 8) {
            Text(session.currentActivity ?? "Awaiting approval")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button("Reject") {
                Task { await SessionManager.shared.rejectHITL(sessionID: session.sessionID) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .foregroundStyle(.red)
            Button("Approve") {
                Task { await SessionManager.shared.approveHITL(sessionID: session.sessionID) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.green)
        }
    }

    // MARK: - Messages preview + reply box

    private var messagesPreview: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(session.recentMessages.prefix(3), id: \.self) { msg in
                Text(msg)
                    .font(.system(.caption2, design: .default))
                    .foregroundStyle(.primary.opacity(0.75))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.bottom, 2)
    }

    private var replyBox: some View {
        HStack(spacing: 6) {
            TextField("Reply to Claude…", text: $replyText)
                .font(.caption)
                .textFieldStyle(.plain)
                .onSubmit { sendReply() }
            Button(action: sendReply) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(replyText.isEmpty ? Color.secondary : Color.blue)
            }
            .buttonStyle(.plain)
            .disabled(replyText.isEmpty)
        }
    }

    private func sendReply() {
        guard !replyText.isEmpty else { return }
        let text = replyText
        replyText = ""
        NotificationCenter.default.post(
            name: NSNotification.Name("ClaudeTerminal.SessionReply"),
            object: nil,
            userInfo: ["cwd": session.cwd, "text": text]
        )
    }

    // MARK: - Badges

    @ViewBuilder
    private var tokenBadge: some View {
        let total = session.totalInputTokens + session.totalOutputTokens
        if total > 0 {
            let cost = Double(session.totalInputTokens) * 3.0 / 1_000_000
                     + Double(session.totalOutputTokens) * 15.0 / 1_000_000
                     + Double(session.totalCacheReadTokens) * 0.30 / 1_000_000
            let tokLabel = total >= 1000
                ? String(format: "%.1fk tok", Double(total) / 1000)
                : "\(total) tok"
            Text("\(tokLabel) · \(String(format: "$%.2f", cost))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var subAgentBadge: some View {
        if session.subAgentCount > 0 {
            Text("×\(session.subAgentCount) sub")
                .font(.caption.bold())
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.gray.opacity(0.2))
                .foregroundStyle(.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    // MARK: - Status dot

    @ViewBuilder
    private var statusDot: some View {
        switch session.status {
        case .running:
            Image(systemName: "circle.fill").foregroundStyle(.green)
        case .awaitingInput:
            Image(systemName: "circle.fill").foregroundStyle(.orange)
        case .completed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.secondary)
        case .blocked:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    // MARK: - Card styling

    private var cardBackground: Color {
        switch session.status {
        case .awaitingInput: return Color.orange.opacity(0.08)
        case .blocked:       return Color.red.opacity(0.06)
        default:             return Color(NSColor.controlBackgroundColor)
        }
    }

    private var borderColor: Color {
        switch session.status {
        case .awaitingInput: return Color.orange.opacity(0.4)
        case .blocked:       return Color.red.opacity(0.3)
        default:             return Color(NSColor.separatorColor).opacity(0.5)
        }
    }

    private func formatElapsed(_ from: Date) -> String {
        let s = Int(Date().timeIntervalSince(from))
        if s < 60 { return "\(s)s" }
        let m = s / 60; let sec = s % 60
        if m < 60 { return "\(m)m \(sec)s" }
        return "\(m / 60)h \(m % 60)m"
    }
}

// MARK: - Previews

#Preview("Running") {
    var session = AgentSession(sessionID: "prev-1", cwd: "/Users/dev/git/claude-terminal/.claude/worktrees/agent-card-ui")
    session.status = .running
    session.currentActivity = "$ swift build -c release"
    session.totalInputTokens = 48_200
    session.totalOutputTokens = 12_400
    session.subAgentCount = 2
    session.recentMessages = [
        "I've analyzed the codebase and found 3 files to modify.",
        "Running build to verify changes compile correctly.",
        "Build succeeded — ready to open a PR."
    ]
    return AgentCardView(session: session)
        .padding()
        .frame(width: 360)
}

#Preview("Awaiting HITL") {
    var session = AgentSession(sessionID: "prev-2", cwd: "/Users/dev/git/my-app/.claude/worktrees/fix-crash")
    session.status = .awaitingInput
    session.currentActivity = "Agent wants to run: rm -rf .build"
    return AgentCardView(session: session)
        .padding()
        .frame(width: 360)
}

#Preview("Completed") {
    var session = AgentSession(sessionID: "prev-3", cwd: "/Users/dev/git/api-service")
    session.status = .completed
    session.currentActivity = "Completed"
    session.totalInputTokens = 120_500
    session.totalOutputTokens = 41_200
    return AgentCardView(session: session)
        .padding()
        .frame(width: 360)
}
