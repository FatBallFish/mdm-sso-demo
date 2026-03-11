import DemoLoginPluginSupport
import XCTest
@testable import DemoLoginShellSupport

@MainActor
final class PreLoginPanelViewModelTests: XCTestCase {
    func test_submit_sets_completed_result_for_success_action() async throws {
        let viewModel = PreLoginPanelViewModel { action in
            XCTAssertEqual(action, .validateSuccess)
            return .allow(localShortName: "demouser", authSource: .http)
        }

        await viewModel.submit(action: .validateSuccess)

        XCTAssertEqual(viewModel.completedResult, .allow(localShortName: "demouser", authSource: .http))
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isSubmitting)
    }

    func test_submit_keeps_panel_open_on_failed_validation_action() async {
        let viewModel = PreLoginPanelViewModel { action in
            XCTAssertEqual(action, .validateFailure)
            return .deny(message: "Demo validation failed.")
        }

        await viewModel.submit(action: .validateFailure)

        XCTAssertNil(viewModel.completedResult)
        XCTAssertEqual(viewModel.errorMessage, "Demo validation failed.")
        XCTAssertFalse(viewModel.isSubmitting)
    }

    func test_cancel_sets_user_canceled_result() {
        let viewModel = PreLoginPanelViewModel { _ in
            XCTFail("validator should not be called on cancel")
            return .deny(message: "unexpected")
        }

        viewModel.cancel()

        XCTAssertEqual(viewModel.completedResult, .userCanceled)
    }
}
