import XCTest
@testable import DemoShared

final class TokenRefreshSchedulerTests: XCTestCase {
    func test_refresh_is_requested_when_token_expires_within_ten_minutes() {
        let scheduler = TokenRefreshScheduler(refreshLeadTime: 600)
        let shouldRefresh = scheduler.shouldRefresh(now: 1_000, expiry: 1_500)

        XCTAssertTrue(shouldRefresh)
    }

    func test_refresh_is_skipped_when_token_expiry_is_far_enough_away() {
        let scheduler = TokenRefreshScheduler(refreshLeadTime: 600)
        let shouldRefresh = scheduler.shouldRefresh(now: 1_000, expiry: 3_000)

        XCTAssertFalse(shouldRefresh)
    }
}
