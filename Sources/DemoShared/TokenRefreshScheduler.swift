import Foundation

public struct TokenRefreshScheduler {
    public let refreshLeadTime: TimeInterval

    public init(refreshLeadTime: TimeInterval) {
        self.refreshLeadTime = refreshLeadTime
    }

    public func shouldRefresh(now: TimeInterval, expiry: TimeInterval) -> Bool {
        expiry - now <= refreshLeadTime
    }
}
