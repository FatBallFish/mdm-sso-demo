import SwiftUI

public struct NativeLoginShellView: View {
    @ObservedObject private var viewModel: LoginViewModel
    private let signInAction: @MainActor () async -> Void
    private let bindAction: @MainActor () async -> Void
    private let createAction: @MainActor () async -> Void

    public init(
        viewModel: LoginViewModel,
        signInAction: @escaping @MainActor () async -> Void,
        bindAction: @escaping @MainActor () async -> Void,
        createAction: @escaping @MainActor () async -> Void
    ) {
        self.viewModel = viewModel
        self.signInAction = signInAction
        self.bindAction = bindAction
        self.createAction = createAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Demo SSO Login")
                .font(.system(size: 28, weight: .semibold))
            credentialsForm
            content
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 320)
    }

    private var credentialsForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Username", text: $viewModel.username)
                .textFieldStyle(.roundedBorder)
            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(.roundedBorder)
            Toggle("Network available", isOn: $viewModel.networkAvailable)
            Button(viewModel.isSubmitting ? "Signing In..." : "Sign In") {
                Task { await signInAction() }
            }
            .disabled(viewModel.isSubmitting || viewModel.username.isEmpty || viewModel.password.isEmpty)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.screen {
        case .credentials:
            VStack(alignment: .leading, spacing: 12) {
                Text("Sign in with your SSO account to continue macOS login.")
                Text("Accounts: demo.user, it.admin, qa.user")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case let .accountBinding(subject):
            VStack(alignment: .leading, spacing: 12) {
                Text("No local account is bound to \(subject).")
                Text("Choose an existing local account or create a new mapped account.")
                    .foregroundStyle(.secondary)
                TextField("Local short name", text: $viewModel.bindingLocalShortName)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Bind Existing Account") {
                        Task { await bindAction() }
                    }
                    Button("Create Local Account") {
                        Task { await createAction() }
                    }
                }
            }
        case let .offline(localShortName):
            VStack(alignment: .leading, spacing: 12) {
                Text("Offline login allowed for \(localShortName).")
                Text("The device is within the cached offline grace window.")
                    .foregroundStyle(.secondary)
            }
        case let .success(localShortName):
            VStack(alignment: .leading, spacing: 12) {
                Text("Login allowed for \(localShortName).")
                Text("The LoginWindow plug-in can now continue local sign-in.")
                    .foregroundStyle(.secondary)
            }
        case let .failure(message):
            VStack(alignment: .leading, spacing: 12) {
                Text("Authentication failed.")
                Text(message)
                    .foregroundStyle(.red)
            }
        }
    }
}
