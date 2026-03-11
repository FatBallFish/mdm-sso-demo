import Foundation

public struct AccountMapping: Codable, Equatable, Sendable {
    public let ssoSubject: String
    public let localShortName: String
    public let lastOnlineAuthAt: Date
    public let offlineGraceExpiry: Date
    public let lastTokenRefreshAt: Date?
    public let lastPasswordFingerprint: String?

    public init(
        ssoSubject: String,
        localShortName: String,
        lastOnlineAuthAt: Date,
        offlineGraceExpiry: Date,
        lastTokenRefreshAt: Date?,
        lastPasswordFingerprint: String? = nil
    ) {
        self.ssoSubject = ssoSubject
        self.localShortName = localShortName
        self.lastOnlineAuthAt = lastOnlineAuthAt
        self.offlineGraceExpiry = offlineGraceExpiry
        self.lastTokenRefreshAt = lastTokenRefreshAt
        self.lastPasswordFingerprint = lastPasswordFingerprint
    }
}

public enum DemoConfiguration {
    public static let defaultOfflineGraceDays = 7
    public static let defaultListenHost = "127.0.0.1"
    public static let defaultListenPort = 48080
}
