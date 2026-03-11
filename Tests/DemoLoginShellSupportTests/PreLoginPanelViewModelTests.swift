import DemoLoginPluginSupport
import XCTest
@testable import DemoLoginShellSupport

@MainActor
final class PreLoginPanelViewModelTests: XCTestCase {
    func test_submit_sets_completed_result_for_valid_credentials() async throws {
        let viewModel = PreLoginPanelViewModel { username, password in
            XCTAssertEqual(username, "demo.user")
            XCTAssertEqual(password, "DemoPass123!")
            return .allow(localShortName: "demouser", authSource: .http)
        }
        viewModel.username = "demo.user"
        viewModel.password = "DemoPass123!"

        await viewModel.submit()

        XCTAssertEqual(viewModel.completedResult, .allow(localShortName: "demouser", authSource: .http))
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isSubmitting)
    }

    func test_submit_keeps_panel_open_on_denied_credentials() async {
        let viewModel = PreLoginPanelViewModel { _, _ in
            .deny(message: "SSO authentication failed.")
        }
        viewModel.username = "demo.user"
        viewModel.password = "wrong"

        await viewModel.submit()

        XCTAssertNil(viewModel.completedResult)
        XCTAssertEqual(viewModel.errorMessage, "SSO authentication failed.")
        XCTAssertFalse(viewModel.isSubmitting)
    }

    func test_cancel_sets_user_canceled_result() {
        let viewModel = PreLoginPanelViewModel { _, _ in
            XCTFail("validator should not be called on cancel")
            return .deny(message: "unexpected")
        }

        viewModel.cancel()

        XCTAssertEqual(viewModel.completedResult, .userCanceled)
    }
}
