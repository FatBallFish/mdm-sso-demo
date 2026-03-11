import AppKit
@testable import DemoLoginShellSupport
import XCTest

@MainActor
final class PreLoginWindowSupportTests: XCTestCase {
    func test_configurePreLoginWindow_enables_visibility_before_login() {
        let window = NSWindow()

        configurePreLoginWindow(window)

        XCTAssertTrue(window.canBecomeVisibleWithoutLogin)
    }
}
