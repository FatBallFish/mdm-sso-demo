import DemoShared
import Foundation

public struct PluginCredentialValidator: Sendable {
    private let remoteIDP: PluginRemoteIDPValidating
    private let fallbackAuthenticator: DemoAuthenticator

    public init(
        remoteIDP: PluginRemoteIDPValidating,
        fallbackAuthenticator: DemoAuthenticator = DemoAuthenticator(configuration: .seeded)
    ) {
        self.remoteIDP = remoteIDP
        self.fallbackAuthenticator = fallbackAuthenticator
    }

    public func validate(username: String, password: String) async throws -> PreLoginAuthResult {
        do {
            try await remoteIDP.checkHealth()
            let token = try await remoteIDP.login(username: username, password: password)
            return .allow(localShortName: token.localShortName, authSource: .http)
        } catch let error as DemoAuthError {
            switch error {
            case .invalidCredentials:
                return fallback(username: username, password: password)
            case .invalidRefreshToken, .serviceUnavailable:
                return fallback(username: username, password: password)
            }
        } catch {
            return fallback(username: username, password: password)
        }
    }

    private func fallback(username: String, password: String) -> PreLoginAuthResult {
        guard let account = fallbackAuthenticator.matchingAccount(username: username, password: password) else {
            return .deny(message: "SSO authentication failed.")
        }

        return .allow(localShortName: account.localShortName, authSource: .fallback)
    }
}
