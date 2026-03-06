import SwiftUI

struct WorkSessionRowView: View {
    let workSession: WorkSession

    @State private var messageText = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                urgencyDot
                VStack(alignment: .leading, spacing: 2) {
                    Text(workSession.displayTitle)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(workSession.worktree.branch)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if let activity = workSession.session?.currentActivity,
                           workSession.urgency != .hitlPending {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text(activity)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
                Spacer()
                if workSession.urgency == .hitlPending {
                    hitlButtons
                }
            }
            if workSession.session != nil {
                messageInputRow
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Message input

    private var messageInputRow: some View {
        HStack(spacing: 6) {
            TextField("Message agent…", text: $messageText)
                .textFieldStyle(.plain)
                .font(.caption)
                .focused($inputFocused)
                .onSubmit(sendMessage)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quinary)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(messageText.isEmpty ? Color.secondary.opacity(0.4) : Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(messageText.isEmpty)
        }
        .padding(.leading, 18) // align with text below the dot
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let bytes = Array(text.utf8) + [0x0d]
        TerminalRegistry.shared.sendInput(bytes, forCwd: workSession.worktree.path)
        messageText = ""
    }

    // MARK: - Inline HITL

    private var hitlButtons: some View {
        HStack(spacing: 8) {
            if let activity = workSession.session?.currentActivity {
                Text(activity)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 160, alignment: .trailing)
            }
            Button("Approve") {
                guard let sessionID = workSession.session?.sessionID else { return }
                Task { await SessionManager.shared.approveHITL(sessionID: sessionID) }
            }
            // .buttonStyle(.plain) required — macOS List rows swallow button taps otherwise (FB12285575)
            .buttonStyle(.plain)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.15))
            .foregroundStyle(.green)
            .clipShape(Capsule())

            Button("Reject") {
                guard let sessionID = workSession.session?.sessionID else { return }
                Task { await SessionManager.shared.rejectHITL(sessionID: sessionID) }
            }
            .buttonStyle(.plain)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.15))
            .foregroundStyle(.red)
            .clipShape(Capsule())
        }
    }

    // MARK: - Urgency dot

    private var urgencyDot: some View {
        Circle()
            .fill(urgencyColor)
            .frame(width: 8, height: 8)
    }

    private var urgencyColor: Color {
        switch workSession.urgency {
        case .hitlPending: return .orange
        case .error:       return .red
        case .running:     return .green
        case .done:        return .blue
        case .idle:        return Color.secondary.opacity(0.3)
        }
    }
}
