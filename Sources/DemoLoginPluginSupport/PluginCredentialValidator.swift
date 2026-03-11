import DemoShared
import Foundation
import os

public struct PluginCredentialValidator: Sendable {
    private static let logger = Logger(subsystem: "com.demo.sso.login-plugin", category: "prelogin-auth")
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
        Self.logger.info("pre-login auth attempt username=\(username, privacy: .public)")
        do {
            try await remoteIDP.checkHealth()
            Self.logger.info("auth_source=http health=ok username=\(username, privacy: .public)")
            let token = try await remoteIDP.login(username: username, password: password)
            Self.logger.info("auth_source=http result=allow localShortName=\(token.localShortName, privacy: .public)")
            return .allow(localShortName: token.localShortName, authSource: .http)
        } catch let error as DemoAuthError {
            switch error {
            case .invalidCredentials:
                Self.logger.info("auth_source=fallback reason=http_invalid_credentials username=\(username, privacy: .public)")
                return fallback(username: username, password: password)
            case .invalidRefreshToken, .serviceUnavailable:
                Self.logger.info("auth_source=fallback reason=service_unavailable username=\(username, privacy: .public)")
                return fallback(username: username, password: password)
            }
        } catch {
            Self.logger.info("auth_source=fallback reason=unexpected_error username=\(username, privacy: .public)")
            return fallback(username: username, password: password)
        }
    }

    private func fallback(username: String, password: String) -> PreLoginAuthResult {
        guard let account = fallbackAuthenticator.matchingAccount(username: username, password: password) else {
            Self.logger.error("auth_source=fallback result=deny username=\(username, privacy: .public)")
            return .deny(message: "SSO authentication failed.")
        }

        Self.logger.info("auth_source=fallback result=allow localShortName=\(account.localShortName, privacy: .public)")
        return .allow(localShortName: account.localShortName, authSource: .fallback)
    }
}
