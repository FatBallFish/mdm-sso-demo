import XCTest
@testable import DemoLoginPluginSupport

final class PreLoginHelperPayloadTests: XCTestCase {
    func test_allow_payload_uses_local_short_name_as_username() {
        let payload = PreLoginHelperPayload(
            result: .allow(localShortName: "demouser", authSource: .http),
            password: "DemoPass123!"
        )

        XCTAssertEqual(payload.action, "allow")
        XCTAssertEqual(payload.username, "demouser")
        XCTAssertEqual(payload.localShortName, "demouser")
        XCTAssertEqual(payload.password, "DemoPass123!")
        XCTAssertEqual(payload.authSource, "http")
        XCTAssertNil(payload.message)
    }

    func test_deny_payload_keeps_message_only() {
        let payload = PreLoginHelperPayload(
            result: .deny(message: "SSO authentication failed."),
            password: "ignored"
        )

        XCTAssertEqual(payload.action, "deny")
        XCTAssertEqual(payload.message, "SSO authentication failed.")
        XCTAssertNil(payload.username)
        XCTAssertNil(payload.localShortName)
        XCTAssertNil(payload.password)
        XCTAssertNil(payload.authSource)
    }

    func test_cancel_payload_is_user_canceled() {
        let payload = PreLoginHelperPayload(result: .userCanceled, password: "ignored")

        XCTAssertEqual(payload.action, "userCanceled")
        XCTAssertNil(payload.username)
        XCTAssertNil(payload.localShortName)
        XCTAssertNil(payload.password)
        XCTAssertNil(payload.message)
    }
}
