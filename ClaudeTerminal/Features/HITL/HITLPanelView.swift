import SwiftUI

/// Shared observable state for the HITL floating panel.
///
/// Using a state object instead of `NSHostingView.rootView =` avoids triggering
/// `setNeedsUpdateConstraints` during AppKit layout cycles (crash in macOS 26).
@Observable
final class HITLPanelState {
    var pendingItems: [HITLItem] = []
}

/// Queue of all pending HITL approval requests, shown in a floating panel.
/// Each item is independent — approving or rejecting one does not affect others.
struct HITLQueueView: View {
    let state: HITLPanelState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(state.pendingItems, id: \.sessionID) { item in
                        ApprovalCardView(item: item)
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 440, height: 360)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Approval Required")
                .font(.headline)
            Spacer()
            if state.pendingItems.count > 1 {
                Text("\(state.pendingItems.count) pending")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview("Single item") {
    let state = HITLPanelState()
    state.pendingItems = [
        HITLItem(
            sessionID: "preview-session-1",
            description: "rm -rf .build && swift build -c release",
            toolName: "Bash",
            riskLevel: .critical,
            onApprove: {},
            onReject: { _ in }
        )
    ]
    return HITLQueueView(state: state)
}

#Preview("Multiple items") {
    let state = HITLPanelState()
    state.pendingItems = [
        HITLItem(
            sessionID: "preview-session-1",
            description: "git push origin worktree-my-feature",
            toolName: "Bash",
            riskLevel: .elevated,
            onApprove: {},
            onReject: { _ in }
        ),
        HITLItem(
            sessionID: "preview-session-2",
            description: "gh pr merge 42 --squash",
            toolName: "Bash",
            riskLevel: .normal,
            onApprove: {},
            onReject: { _ in }
        )
    ]
    return HITLQueueView(state: state)
}
