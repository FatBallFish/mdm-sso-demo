public struct MechanismDispositionPayload: Codable, Equatable, Sendable {
    public let action: String
    public let localShortName: String?
    public let subject: String?
    public let message: String?

    public init(disposition: MechanismDisposition) {
        switch disposition {
        case let .allowLogin(localShortName):
            self.action = "allowLogin"
            self.localShortName = localShortName
            self.subject = nil
            self.message = nil
        case let .promptForAccountBinding(subject):
            self.action = "promptForAccountBinding"
            self.localShortName = nil
            self.subject = subject
            self.message = nil
        case let .allowOffline(localShortName):
            self.action = "allowOffline"
            self.localShortName = localShortName
            self.subject = nil
            self.message = nil
        case let .deny(message):
            self.action = "deny"
            self.localShortName = nil
            self.subject = nil
            self.message = message
        }
    }
}
