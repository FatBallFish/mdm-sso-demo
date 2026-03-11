import SwiftUI

public struct PluginPreLoginView: View {
    @ObservedObject private var viewModel: PreLoginPanelViewModel

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

                Text("Authenticate with the demo IdP before the native macOS login flow continues.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.82))

                VStack(alignment: .leading, spacing: 12) {
                    TextField("SSO username", text: $viewModel.username)
                        .textFieldStyle(.roundedBorder)
                    SecureField("SSO password", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)

                    Text("The shell first calls the local HTTP IdP. If it is unavailable, the seeded demo credentials are used as fallback.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.red)
                    }

                    HStack {
                        Button("Cancel") {
                            viewModel.cancel()
                        }
                        .keyboardShortcut(.cancelAction)

                        Spacer()

                        Button(viewModel.isSubmitting ? "Signing In..." : "Sign In") {
                            Task { await viewModel.submit() }
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(viewModel.isSubmitting || viewModel.username.isEmpty || viewModel.password.isEmpty)
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
