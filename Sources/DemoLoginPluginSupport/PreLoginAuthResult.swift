public enum PreLoginAuthSource: String, Equatable, Sendable {
    case http
    case fallback
}

public enum PreLoginAuthResult: Equatable, Sendable {
    case allow(localShortName: String, authSource: PreLoginAuthSource)
    case deny(message: String)
    case userCanceled
}
