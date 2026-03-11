import XCTest
@testable import DemoLoginShellSupport

final class RuntimeConfigurationTests: XCTestCase {
    func test_daemon_path_prefers_explicit_environment_variable() {
        let url = DemoRuntimeConfiguration.resolveDaemonExecutableURL(
            environment: ["DEMO_ACCOUNTSYNC_DAEMON_PATH": "/tmp/custom-daemon"],
            executablePath: "/Applications/DemoLoginShell",
            currentDirectoryPath: "/tmp",
            fileExists: { _ in false }
        )

        XCTAssertEqual(url.path, "/tmp/custom-daemon")
    }

    func test_daemon_path_uses_sibling_binary_when_present() {
        let url = DemoRuntimeConfiguration.resolveDaemonExecutableURL(
            environment: [:],
            executablePath: "/Library/Application Support/DemoSSO/bin/DemoLoginShell",
            currentDirectoryPath: "/tmp",
            fileExists: { path in
                path == "/Library/Application Support/DemoSSO/bin/DemoAccountSyncDaemon"
            }
        )

        XCTAssertEqual(url.path, "/Library/Application Support/DemoSSO/bin/DemoAccountSyncDaemon")
    }

    func test_daemon_path_falls_back_to_build_directory() {
        let url = DemoRuntimeConfiguration.resolveDaemonExecutableURL(
            environment: [:],
            executablePath: "/usr/local/bin/DemoLoginShell",
            currentDirectoryPath: "/repo",
            fileExists: { _ in false }
        )

        XCTAssertEqual(url.path, "/repo/.build/arm64-apple-macosx/debug/DemoAccountSyncDaemon")
    }
}
