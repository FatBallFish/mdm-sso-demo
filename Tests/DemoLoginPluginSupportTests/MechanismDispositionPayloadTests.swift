import XCTest
@testable import DemoLoginPluginSupport

final class MechanismDispositionPayloadTests: XCTestCase {
    func test_allow_login_payload_serializes_local_short_name() throws {
        let payload = MechanismDispositionPayload(
            disposition: .allowLogin(localShortName: "demouser")
        )

        XCTAssertEqual(payload.action, "allowLogin")
        XCTAssertEqual(payload.localShortName, "demouser")
        XCTAssertNil(payload.subject)
    }

    func test_prompt_binding_payload_serializes_subject() throws {
        let payload = MechanismDispositionPayload(
            disposition: .promptForAccountBinding(subject: "demo.user")
        )

        XCTAssertEqual(payload.action, "promptForAccountBinding")
        XCTAssertEqual(payload.subject, "demo.user")
        XCTAssertNil(payload.localShortName)
    }
}
