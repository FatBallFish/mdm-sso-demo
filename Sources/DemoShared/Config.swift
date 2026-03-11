import Foundation

public struct DemoAccount: Codable, Equatable, Sendable {
    public let username: String
    public let password: String
    public let localShortName: String
    public let displayName: String

    public init(username: String, password: String, localShortName: String, displayName: String) {
        self.username = username
        self.password = password
        self.localShortName = localShortName
        self.displayName = displayName
    }
}

public struct DemoIDPConfiguration: Codable, Equatable, Sendable {
    public let issuer: String
    public let accounts: [DemoAccount]
    public let accessTokenTTLSeconds: Int
    public let refreshTokenTTLSeconds: Int

    public init(
        issuer: String,
        accounts: [DemoAccount],
        accessTokenTTLSeconds: Int = 3600,
        refreshTokenTTLSeconds: Int = 86_400
    ) {
        self.issuer = issuer
        self.accounts = accounts
        self.accessTokenTTLSeconds = accessTokenTTLSeconds
        self.refreshTokenTTLSeconds = refreshTokenTTLSeconds
    }

    public static let seeded = DemoIDPConfiguration(
        issuer: "http://127.0.0.1:48080",
        accounts: [
            DemoAccount(
                username: "demo.user",
                password: "DemoPass123!",
                localShortName: "demouser",
                displayName: "Demo User"
            ),
            DemoAccount(
                username: "it.admin",
                password: "AdminPass123!",
                localShortName: "itadmin",
                displayName: "IT Admin"
            ),
            DemoAccount(
                username: "qa.user",
                password: "QAPass123!",
                localShortName: "qauser",
                displayName: "QA User"
            ),
        ]
    )

    public static func load(from url: URL?) throws -> DemoIDPConfiguration {
        guard let url else {
            return .seeded
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(DemoIDPConfiguration.self, from: data)
    }
}
