import Foundation
import XCTest
@testable import DemoLoginShellSupport

final class LoginShellLaunchOptionsTests: XCTestCase {
    func test_defaults_to_interactive_mode_without_plugin_flags() {
        let options = LoginShellLaunchOptions.parse(
            arguments: ["/tmp/DemoLoginShell"]
        )

        XCTAssertEqual(options.mode, .interactive)
    }

    func test_parses_plugin_mode_with_result_file_and_idp_url() {
        let options = LoginShellLaunchOptions.parse(
            arguments: [
                "/tmp/DemoLoginShell",
                "--plugin-result-file", "/tmp/result.plist",
                "--plugin-idp-base-url", "http://127.0.0.1:48080/"
            ]
        )

        XCTAssertEqual(
            options.mode,
            .plugin(resultFileURL: URL(fileURLWithPath: "/tmp/result.plist"))
        )
        XCTAssertEqual(options.idpBaseURL, URL(string: "http://127.0.0.1:48080/"))
    }
}
