import SwiftUI

public struct PluginPreLoginView: View {
    @ObservedObject private var viewModel: PreLoginPanelViewModel
    private let defaultStatusText = "Use the buttons below to verify the plug-in can allow, deny, or return to the native macOS login screen."

    public init(viewModel: PreLoginPanelViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: NSColor(calibratedRed: 0.07, green: 0.12, blue: 0.18, alpha: 1)),
                    Color(nsColor: NSColor(calibratedRed: 0.14, green: 0.18, blue: 0.24, alpha: 1)),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text("Demo SSO Sign In")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)

                Text("This pre-login demo avoids text input and verifies that the Authorization plug-in can allow, deny, or return to the native login flow.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.82))

                VStack(alignment: .leading, spacing: 12) {
                    Text(viewModel.errorMessage ?? (viewModel.isSubmitting ? "Applying demo validation..." : defaultStatusText))
                        .font(.caption)
                        .foregroundStyle(viewModel.errorMessage == nil ? Color.secondary : Color.red)

                    VStack(alignment: .leading, spacing: 10) {
                        Button(viewModel.isSubmitting ? "Validating..." : "Validate Success") {
                            Task { await viewModel.submit(action: .validateSuccess) }
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(viewModel.isSubmitting)

                        Button("Validate Failure") {
                            Task { await viewModel.submit(action: .validateFailure) }
                        }
                        .disabled(viewModel.isSubmitting)

                        Button("Back To macOS Login") {
                            viewModel.cancel()
                        }
                        .keyboardShortcut(.cancelAction)
                        .disabled(viewModel.isSubmitting)
                    }
                }
                .padding(20)
                .background(Color.white.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(28)
            .frame(width: 560)
        }
        .frame(minWidth: 620, minHeight: 340)
    }
}
