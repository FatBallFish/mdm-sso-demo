import Foundation

public struct DemoLoginRequest: Codable, Equatable, Sendable {
    public let username: String
    public let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

public struct DemoRefreshRequest: Codable, Equatable, Sendable {
    public let refreshToken: String

    public init(refreshToken: String) {
        self.refreshToken = refreshToken
    }
}

public struct DemoTokenResponse: Codable, Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresInSeconds: Int
    public let subject: String
    public let localShortName: String

    public init(
        accessToken: String,
        refreshToken: String,
        expiresInSeconds: Int,
        subject: String,
        localShortName: String
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresInSeconds = expiresInSeconds
        self.subject = subject
        self.localShortName = localShortName
    }
}

public struct DemoErrorResponse: Codable, Equatable, Sendable {
    public let error: String
    public let message: String

    public init(error: String, message: String) {
        self.error = error
        self.message = message
    }
}
