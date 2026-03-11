import DemoLoginPluginSupport
import AppKit
import XCTest
@testable import DemoLoginShellSupport

@MainActor
final class PluginPreLoginWindowControllerTests: XCTestCase {
    func test_submit_button_requires_username_and_password() {
        let viewModel = PreLoginPanelViewModel { _, _ in
            .allow(localShortName: "demouser", authSource: .fallback)
        }
        let controller = PluginPreLoginWindowController(viewModel: viewModel)
        _ = controller.window

        XCTAssertFalse(controller.submitButton.isEnabled)

        controller.usernameField.stringValue = "demo.user"
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: controller.usernameField))
        XCTAssertFalse(controller.submitButton.isEnabled)

        controller.passwordField.stringValue = "DemoPass123!"
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: controller.passwordField))

        XCTAssertTrue(controller.submitButton.isEnabled)
    }
}
