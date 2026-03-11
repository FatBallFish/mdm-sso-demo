import XCTest
@testable import DemoShared

final class LoginPolicyTests: XCTestCase {
    func test_offline_login_is_denied_after_grace_expiry() {
        let policy = LoginPolicy(now: {
            Date(timeIntervalSince1970: 10_000)
        })

        let record = AccountMapping(
            ssoSubject: "demo.user",
            localShortName: "demouser",
            lastOnlineAuthAt: Date(timeIntervalSince1970: 1_000),
            offlineGraceExpiry: Date(timeIntervalSince1970: 9_999),
            lastTokenRefreshAt: nil
        )

        XCTAssertFalse(policy.isOfflineLoginAllowed(record))
    }
}
