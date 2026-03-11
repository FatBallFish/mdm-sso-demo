import DemoShared
import Foundation

public enum AccountSyncCommand: Codable, Equatable, Sendable {
    case resolveLocalAccount(subject: String)
    case recordSuccessfulOnlineLogin(subject: String, localShortName: String, password: String)
    case verifyOfflineLogin(subject: String, password: String)
    case bindExistingLocalAccount(subject: String, localShortName: String, password: String)
    case createLocalAccount(subject: String, suggestedLocalShortName: String, password: String)

    private enum CodingKeys: String, CodingKey {
        case action
        case subject
        case localShortName
        case password
        case suggestedLocalShortName
    }

    private enum Action: String, Codable {
        case resolveLocalAccount
        case recordSuccessfulOnlineLogin
        case verifyOfflineLogin
        case bindExistingLocalAccount
        case createLocalAccount
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .resolveLocalAccount(subject):
            try container.encode(Action.resolveLocalAccount, forKey: .action)
            try container.encode(subject, forKey: .subject)
        case let .recordSuccessfulOnlineLogin(subject, localShortName, password):
            try container.encode(Action.recordSuccessfulOnlineLogin, forKey: .action)
            try container.encode(subject, forKey: .subject)
            try container.encode(localShortName, forKey: .localShortName)
            try container.encode(password, forKey: .password)
        case let .verifyOfflineLogin(subject, password):
            try container.encode(Action.verifyOfflineLogin, forKey: .action)
            try container.encode(subject, forKey: .subject)
            try container.encode(password, forKey: .password)
        case let .bindExistingLocalAccount(subject, localShortName, password):
            try container.encode(Action.bindExistingLocalAccount, forKey: .action)
            try container.encode(subject, forKey: .subject)
            try container.encode(localShortName, forKey: .localShortName)
            try container.encode(password, forKey: .password)
        case let .createLocalAccount(subject, suggestedLocalShortName, password):
            try container.encode(Action.createLocalAccount, forKey: .action)
            try container.encode(subject, forKey: .subject)
            try container.encode(suggestedLocalShortName, forKey: .suggestedLocalShortName)
            try container.encode(password, forKey: .password)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let action = try container.decode(Action.self, forKey: .action)
        let subject = try container.decode(String.self, forKey: .subject)

        switch action {
        case .resolveLocalAccount:
            self = .resolveLocalAccount(subject: subject)
        case .recordSuccessfulOnlineLogin:
            self = .recordSuccessfulOnlineLogin(
                subject: subject,
                localShortName: try container.decode(String.self, forKey: .localShortName),
                password: try container.decode(String.self, forKey: .password)
            )
        case .verifyOfflineLogin:
            self = .verifyOfflineLogin(
                subject: subject,
                password: try container.decode(String.self, forKey: .password)
            )
        case .bindExistingLocalAccount:
            self = .bindExistingLocalAccount(
                subject: subject,
                localShortName: try container.decode(String.self, forKey: .localShortName),
                password: try container.decode(String.self, forKey: .password)
            )
        case .createLocalAccount:
            self = .createLocalAccount(
                subject: subject,
                suggestedLocalShortName: try container.decode(String.self, forKey: .suggestedLocalShortName),
                password: try container.decode(String.self, forKey: .password)
            )
        }
    }
}

public struct AccountSyncCommandResponse: Codable, Equatable, Sendable {
    public let localShortName: String?
    public let errorMessage: String?

    public init(localShortName: String? = nil, errorMessage: String? = nil) {
        self.localShortName = localShortName
        self.errorMessage = errorMessage
    }
}
