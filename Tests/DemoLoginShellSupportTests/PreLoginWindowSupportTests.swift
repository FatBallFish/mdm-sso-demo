import AppKit
@testable import DemoLoginShellSupport
import XCTest

@MainActor
final class PreLoginWindowSupportTests: XCTestCase {
    func test_configurePreLoginApplication_disables_automatic_window_tabbing() {
        NSWindow.allowsAutomaticWindowTabbing = true
        defer { NSWindow.allowsAutomaticWindowTabbing = true }

        configurePreLoginApplication()

        XCTAssertFalse(NSWindow.allowsAutomaticWindowTabbing)
    }

    func test_configurePreLoginWindow_enables_visibility_before_login() {
        let window = NSWindow()

        configurePreLoginWindow(window)

        XCTAssertTrue(window.canBecomeVisibleWithoutLogin)
        XCTAssertFalse(window.isRestorable)
    }
}
