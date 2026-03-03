import SwiftUI
import SwiftData

/// Sheet displayed after drawing a random bet from the Bet Bowl.
///
/// The caller owns the draw logic and passes the currently drawn bet as a binding.
/// Tapping "Re-draw" invokes `onRedraw` so the parent can pick a new random bet
/// without dismissing and re-presenting the sheet.
struct BetDrawSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// The bet currently on display. Updated in-place via `onRedraw`.
    let bet: Bet

    /// Called when the user taps "Re-draw" — parent picks the next random bet.
    let onRedraw: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 6) {
                Image(systemName: "dice.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.accentColor)
                Text("Next bet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1)
            }

            // Bet title
            Text(bet.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Notes (if any)
            if let notes = bet.notes, !notes.isEmpty {
                Text(notes)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Divider()

            // Actions
            VStack(spacing: 10) {
                Button(action: convertToTask) {
                    Label("Convert to Task", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                HStack(spacing: 12) {
                    Button(action: onRedraw) {
                        Label("Re-draw", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button("Dismiss") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .padding(.top, 28)
        .frame(width: 360)
    }

    // MARK: - Mutations

    private func convertToTask() {
        let task = ClaudeTask(title: bet.title, taskType: "feature")
        task.sortOrder = 0
        task.status = "pending"
        context.insert(task)

        bet.status = "converted"
        bet.convertedTaskID = task.id

        try? context.save()
        dismiss()
    }
}
