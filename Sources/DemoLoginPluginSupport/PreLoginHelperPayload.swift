public struct PreLoginHelperPayload: Codable, Equatable, Sendable {
    public let action: String
    public let username: String?
    public let localShortName: String?
    public let password: String?
    public let authSource: String?
    public let message: String?

    public init(result: PreLoginAuthResult, password: String) {
        switch result {
        case let .allow(localShortName, authSource):
            self.action = "allow"
            self.username = localShortName
            self.localShortName = localShortName
            self.password = password
            self.authSource = authSource.rawValue
            self.message = nil
        case let .deny(message):
            self.action = "deny"
            self.username = nil
            self.localShortName = nil
            self.password = nil
            self.authSource = nil
            self.message = message
        case .userCanceled:
            self.action = "userCanceled"
            self.username = nil
            self.localShortName = nil
            self.password = nil
            self.authSource = nil
            self.message = nil
        }
    }
}
