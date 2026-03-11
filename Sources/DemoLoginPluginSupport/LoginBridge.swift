public enum PluginLoginResult: Equatable {
    case success(localShortName: String)
    case needsAccountBinding(subject: String)
    case offlineAllowed(localShortName: String)
    case failure(message: String)
}

public enum MechanismDisposition: Equatable {
    case allowLogin(localShortName: String)
    case promptForAccountBinding(subject: String)
    case allowOffline(localShortName: String)
    case deny(message: String)
}

public struct LoginPluginBridge {
    public init() {}

    public func map(result: PluginLoginResult) -> MechanismDisposition {
        switch result {
        case let .success(localShortName):
            .allowLogin(localShortName: localShortName)
        case let .needsAccountBinding(subject):
            .promptForAccountBinding(subject: subject)
        case let .offlineAllowed(localShortName):
            .allowOffline(localShortName: localShortName)
        case let .failure(message):
            .deny(message: message)
        }
    }

    public func map(preLoginResult: PreLoginAuthResult) -> MechanismDisposition {
        switch preLoginResult {
        case let .allow(localShortName, _):
            .allowLogin(localShortName: localShortName)
        case let .deny(message):
            .deny(message: message)
        case .userCanceled:
            .deny(message: "User canceled.")
        }
    }
}
