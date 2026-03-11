import XCTest
@testable import DemoLoginPluginSupport

final class LoginPluginBridgeTests: XCTestCase {
    func test_successful_online_login_maps_to_allow_login() {
        let bridge = LoginPluginBridge()

        XCTAssertEqual(
            bridge.map(result: .success(localShortName: "demouser")),
            .allowLogin(localShortName: "demouser")
        )
    }

    func test_unmapped_subject_maps_to_account_binding() {
        let bridge = LoginPluginBridge()

        XCTAssertEqual(
            bridge.map(result: .needsAccountBinding(subject: "demo.user")),
            .promptForAccountBinding(subject: "demo.user")
        )
    }

    func test_failed_login_maps_to_deny() {
        let bridge = LoginPluginBridge()

        XCTAssertEqual(
            bridge.map(result: .failure(message: "bad password")),
            .deny(message: "bad password")
        )
    }
}
