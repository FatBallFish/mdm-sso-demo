import XCTest
@testable import DemoLoginShellSupport

@MainActor
final class LoginViewModelTests: XCTestCase {
    func test_account_binding_prompt_is_shown_for_unmapped_subject() {
        let viewModel = LoginViewModel()

        viewModel.handle(.needsAccountBinding(subject: "demo.user"))

        XCTAssertEqual(viewModel.screen, .accountBinding(subject: "demo.user"))
    }

    func test_success_screen_carries_bound_local_account() {
        let viewModel = LoginViewModel()

        viewModel.handle(.success(localShortName: "demouser"))

        XCTAssertEqual(viewModel.screen, .success(localShortName: "demouser"))
    }

    func test_offline_screen_is_shown_when_offline_login_is_allowed() {
        let viewModel = LoginViewModel()

        viewModel.handle(.offlineLogin(localShortName: "demouser"))

        XCTAssertEqual(viewModel.screen, .offline(localShortName: "demouser"))
    }
}
