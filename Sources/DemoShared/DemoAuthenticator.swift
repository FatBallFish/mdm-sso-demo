import Foundation

public enum DemoAuthError: Error, Equatable, Sendable {
    case invalidCredentials
    case invalidRefreshToken
    case serviceUnavailable
}

public final class DemoAuthenticator: @unchecked Sendable {
    private let configuration: DemoIDPConfiguration
    private var refreshIndex: [String: DemoAccount] = [:]
    private let lock = NSLock()

    public init(configuration: DemoIDPConfiguration) {
        self.configuration = configuration
    }

    public func login(username: String, password: String) throws -> DemoTokenResponse {
        guard let account = matchingAccount(username: username, password: password) else {
            throw DemoAuthError.invalidCredentials
        }

        return issueToken(for: account)
    }

    public func matchingAccount(username: String, password: String) -> DemoAccount? {
        configuration.accounts.first(where: { $0.username == username && $0.password == password })
    }

    public func refresh(refreshToken: String) throws -> DemoTokenResponse {
        lock.lock()
        let account = refreshIndex[refreshToken]
        lock.unlock()

        guard let account else {
            throw DemoAuthError.invalidRefreshToken
        }

        return issueToken(for: account)
    }

    private func issueToken(for account: DemoAccount) -> DemoTokenResponse {
        let response = DemoTokenResponse(
            accessToken: UUID().uuidString,
            refreshToken: UUID().uuidString,
            expiresInSeconds: configuration.accessTokenTTLSeconds,
            subject: account.username,
            localShortName: account.localShortName
        )

        lock.lock()
        refreshIndex[response.refreshToken] = account
        lock.unlock()

        return response
    }
}
