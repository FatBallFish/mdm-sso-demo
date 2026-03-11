import XCTest
@testable import DemoShared

final class DemoAuthenticatorTests: XCTestCase {
    func test_login_succeeds_for_each_seeded_account() throws {
        let configuration = DemoIDPConfiguration.seeded
        let authenticator = DemoAuthenticator(configuration: configuration)

        let first = try authenticator.login(username: "demo.user", password: "DemoPass123!")
        let second = try authenticator.login(username: "it.admin", password: "AdminPass123!")
        let third = try authenticator.login(username: "qa.user", password: "QAPass123!")

        XCTAssertEqual(first.subject, "demo.user")
        XCTAssertEqual(second.subject, "it.admin")
        XCTAssertEqual(third.subject, "qa.user")
    }

    func test_refresh_reuses_subject_from_issued_token() throws {
        let configuration = DemoIDPConfiguration.seeded
        let authenticator = DemoAuthenticator(configuration: configuration)
        let issued = try authenticator.login(username: "demo.user", password: "DemoPass123!")

        let refreshed = try authenticator.refresh(refreshToken: issued.refreshToken)

        XCTAssertEqual(refreshed.subject, "demo.user")
        XCTAssertNotEqual(refreshed.accessToken, issued.accessToken)
    }

    func test_login_rejects_unknown_credentials() {
        let configuration = DemoIDPConfiguration.seeded
        let authenticator = DemoAuthenticator(configuration: configuration)

        XCTAssertThrowsError(try authenticator.login(username: "demo.user", password: "wrong"))
    }
}
