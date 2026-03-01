import SwiftUI

/// First-launch onboarding sheet.
/// Explains what Claude Terminal hooks do and lets the user install them with one tap.
struct OnboardingView: View {
    @Binding var hookStatus: HookInstallStatus
    var onDismiss: () -> Void

    @State private var installError: String?
    @State private var isInstalling = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            steps
            Divider()
            footer
        }
        .frame(width: 460)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)
            Text("Welcome to Claude Terminal")
                .font(.title2.bold())
            Text("Connect Claude Code to this app by installing hooks.\nTakes 2 seconds — fully reversible.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
        .padding(.top, 32)
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
    }

    // MARK: - Steps

    private var steps: some View {
        VStack(alignment: .leading, spacing: 16) {
            hookStep(
                icon: "chart.bar.fill",
                title: "Monitor sessions",
                description: "See every agent's status, current activity, and token spend in real time."
            )
            hookStep(
                icon: "hand.raised.fill",
                title: "Handle HITL approvals",
                description: "Get a notification when an agent needs your approval — approve or reject without switching terminals."
            )
            hookStep(
                icon: "shield.fill",
                title: "Bash command guard",
                description: "Review Bash commands before they run (optional — configurable in settings)."
            )
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
    }

    private func hookStep(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            if let error = installError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            statusRow

            HStack(spacing: 12) {
                if hookStatus != .installed {
                    Button("Skip for now") { onDismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }

                installButton
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
    }

    @ViewBuilder
    private var statusRow: some View {
        switch hookStatus {
        case .installed:
            Label("Hooks installed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline.bold())
        case .outdated(let reason):
            Label("Hooks outdated — \(reason)", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
        case .notInstalled:
            EmptyView()
        }
    }

    @ViewBuilder
    private var installButton: some View {
        if hookStatus == .installed {
            Button("Done") { onDismiss() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        } else {
            Button {
                installHooks()
            } label: {
                if isInstalling {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 80)
                } else {
                    Text("Install Hooks")
                        .frame(width: 80)
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(isInstalling)
        }
    }

    // MARK: - Actions

    private func installHooks() {
        isInstalling = true
        installError = nil
        Task {
            do {
                try await SettingsWriter.shared.installHooks()
                hookStatus = .installed
            } catch {
                installError = error.localizedDescription
            }
            isInstalling = false
        }
    }
}
