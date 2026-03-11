import DemoLoginPluginSupport
import AppKit
import XCTest
@testable import DemoLoginShellSupport

@MainActor
final class PluginPreLoginWindowControllerTests: XCTestCase {
    func test_controller_exposes_three_demo_action_buttons() {
        let viewModel = PreLoginPanelViewModel { _ in
            .allow(localShortName: "demouser", authSource: .fallback)
        }
        let controller = PluginPreLoginWindowController(viewModel: viewModel)
        _ = controller.window

        XCTAssertEqual(controller.successButton.title, "Validate Success")
        XCTAssertEqual(controller.failureButton.title, "Validate Failure")
        XCTAssertEqual(controller.cancelButton.title, "Back To macOS Login")
    }

    func test_default_status_text_is_instructional() {
        let viewModel = PreLoginPanelViewModel { _ in
            .allow(localShortName: "demouser", authSource: .fallback)
        }
        let controller = PluginPreLoginWindowController(viewModel: viewModel)
        _ = controller.window

        XCTAssertEqual(
            controller.statusLabel.stringValue,
            "Use the buttons below to verify the plug-in can allow, deny, or return to the native macOS login screen."
        )
    }

    func test_failure_message_updates_status_label() async {
        let viewModel = PreLoginPanelViewModel { action in
            XCTAssertEqual(action, .validateFailure)
            return .deny(message: "Demo validation failed.")
        }
        let controller = PluginPreLoginWindowController(viewModel: viewModel)
        _ = controller.window

        controller.validateFailurePressed(nil)
        let failureShown = expectation(description: "failure shown")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            failureShown.fulfill()
        }
        await fulfillment(of: [failureShown], timeout: 1.0)

        for _ in 0..<50 where (!controller.successButton.isEnabled || !controller.failureButton.isEnabled || !controller.cancelButton.isEnabled) {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(controller.statusLabel.stringValue, "Demo validation failed.")
        XCTAssertNil(viewModel.completedResult)
        XCTAssertTrue(controller.successButton.isEnabled)
        XCTAssertTrue(controller.failureButton.isEnabled)
        XCTAssertTrue(controller.cancelButton.isEnabled)
    }
}
