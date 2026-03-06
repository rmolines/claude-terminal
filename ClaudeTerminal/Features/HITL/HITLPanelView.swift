import SwiftUI

/// Shared observable state for the HITL floating panel.
///
/// Using a state object instead of `NSHostingView.rootView =` avoids triggering
/// `setNeedsUpdateConstraints` during AppKit layout cycles (crash in macOS 26).
@Observable
final class HITLPanelState {
    var sessionID: String = ""
    var description: String = ""
    var onApprove: () -> Void = {}
    var onReject: () -> Void = {}
}

/// Inline HITL approval panel — shows what the agent wants to do and approve/reject controls.
struct HITLPanelView: View {
    let state: HITLPanelState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Approval Required", systemImage: "exclamationmark.triangle")
                .font(.headline)

            Text(state.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Reject", role: .destructive) { state.onReject() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Approve") { state.onApprove() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400, height: 140)
    }
}

#Preview("Approval required") {
    let state = HITLPanelState()
    state.sessionID = "preview-session-1"
    state.description = "Agent wants to run: rm -rf .build && swift build -c release"
    return HITLPanelView(state: state)
}

#Preview("Bash command guard") {
    let state = HITLPanelState()
    state.sessionID = "preview-session-2"
    state.description = "Agent wants to execute: gh pr merge 42 --squash"
    return HITLPanelView(state: state)
}
