import Foundation

public struct LoginPolicy {
    private let now: () -> Date

    public init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    public func isOfflineLoginAllowed(_ record: AccountMapping) -> Bool {
        now() < record.offlineGraceExpiry
    }
}
