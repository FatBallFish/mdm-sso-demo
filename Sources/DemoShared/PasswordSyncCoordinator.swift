public enum PasswordSyncAction: Equatable, Sendable {
    case noop
    case rotateLocalPassword
}

public struct PasswordSyncCoordinator {
    public init() {}

    public func reconcile(localPasswordFingerprint: String, remotePasswordFingerprint: String) -> PasswordSyncAction {
        localPasswordFingerprint == remotePasswordFingerprint ? .noop : .rotateLocalPassword
    }
}
