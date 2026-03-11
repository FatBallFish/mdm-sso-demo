import DemoLoginPluginSupport
import AppKit
import XCTest
@testable import DemoLoginShellSupport

@MainActor
final class PluginPreLoginWindowControllerTests: XCTestCase {
    func test_text_fields_disable_modern_text_features() {
        let viewModel = PreLoginPanelViewModel { _, _ in
            .allow(localShortName: "demouser", authSource: .fallback)
        }
        let controller = PluginPreLoginWindowController(viewModel: viewModel)
        _ = controller.window

        XCTAssertFalse(controller.usernameField.isAutomaticTextCompletionEnabled)
        XCTAssertFalse(controller.passwordField.isAutomaticTextCompletionEnabled)
        XCTAssertFalse(controller.usernameField.allowsCharacterPickerTouchBarItem)
        XCTAssertFalse(controller.passwordField.allowsCharacterPickerTouchBarItem)

        if #available(macOS 15.2, *) {
            XCTAssertFalse(controller.usernameField.allowsWritingTools)
            XCTAssertFalse(controller.passwordField.allowsWritingTools)
        }
    }

    func test_begin_editing_disables_field_editor_text_services() {
        let viewModel = PreLoginPanelViewModel { _, _ in
            .allow(localShortName: "demouser", authSource: .fallback)
        }
        let controller = PluginPreLoginWindowController(viewModel: viewModel)
        _ = controller.window

        let fieldEditor = NSTextView(frame: .zero)
        fieldEditor.isAutomaticTextCompletionEnabled = true
        fieldEditor.isContinuousSpellCheckingEnabled = true
        fieldEditor.isGrammarCheckingEnabled = true
        fieldEditor.smartInsertDeleteEnabled = true
        fieldEditor.isAutomaticQuoteSubstitutionEnabled = true
        fieldEditor.isAutomaticDashSubstitutionEnabled = true
        fieldEditor.isAutomaticTextReplacementEnabled = true
        fieldEditor.isAutomaticSpellingCorrectionEnabled = true
        fieldEditor.isAutomaticLinkDetectionEnabled = true
        fieldEditor.isAutomaticDataDetectionEnabled = true
        if #available(macOS 15.0, *) {
            fieldEditor.writingToolsBehavior = .default
        }

        let notification = Notification(
            name: NSControl.textDidBeginEditingNotification,
            object: controller.usernameField,
            userInfo: ["NSFieldEditor": fieldEditor]
        )
        controller.controlTextDidBeginEditing(notification)

        XCTAssertFalse(fieldEditor.isAutomaticTextCompletionEnabled)
        XCTAssertFalse(fieldEditor.isContinuousSpellCheckingEnabled)
        XCTAssertFalse(fieldEditor.isGrammarCheckingEnabled)
        XCTAssertFalse(fieldEditor.smartInsertDeleteEnabled)
        XCTAssertFalse(fieldEditor.isAutomaticQuoteSubstitutionEnabled)
        XCTAssertFalse(fieldEditor.isAutomaticDashSubstitutionEnabled)
        XCTAssertFalse(fieldEditor.isAutomaticTextReplacementEnabled)
        XCTAssertFalse(fieldEditor.isAutomaticSpellingCorrectionEnabled)
        XCTAssertFalse(fieldEditor.isAutomaticLinkDetectionEnabled)
        XCTAssertFalse(fieldEditor.isAutomaticDataDetectionEnabled)
        if #available(macOS 15.0, *) {
            XCTAssertEqual(fieldEditor.writingToolsBehavior, .none)
        }
    }

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
