import SwiftUI

/// Inline HITL approval panel — shows what the agent wants to do and approve/reject controls.
struct HITLPanelView: View {
    let sessionID: String
    let description: String
    var onApprove: () -> Void = {}
    var onReject: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Approval Required", systemImage: "exclamationmark.triangle")
                .font(.headline)

            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)

            HStack {
                Button("Reject", role: .destructive, action: onReject)
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Approve", action: onApprove)
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
