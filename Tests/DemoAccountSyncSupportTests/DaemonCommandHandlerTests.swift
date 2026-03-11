import XCTest
@testable import DemoAccountSyncSupport

final class DaemonCommandHandlerTests: XCTestCase {
    func test_resolve_command_returns_bound_local_short_name() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = AccountSyncService(baseURL: tempDir)
        let handler = AccountSyncCommandHandler(accountSync: service)
        _ = try service.bindExistingLocalAccount(
            subject: "demo.user",
            localShortName: "existinguser",
            password: "DemoPass123!"
        )

        let response = try handler.handle(.resolveLocalAccount(subject: "demo.user"))

        XCTAssertEqual(response.localShortName, "existinguser")
    }

    func test_create_account_command_returns_created_mapping() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = AccountSyncService(baseURL: tempDir)
        let handler = AccountSyncCommandHandler(accountSync: service)

        let response = try handler.handle(
            .createLocalAccount(
                subject: "demo.user",
                suggestedLocalShortName: "demouser",
                password: "DemoPass123!"
            )
        )

        XCTAssertEqual(response.localShortName, "demouser")
    }

    func test_offline_verification_command_returns_cached_mapping() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = AccountSyncService(baseURL: tempDir, now: { Date(timeIntervalSince1970: 1_000) })
        let handler = AccountSyncCommandHandler(accountSync: service)
        _ = try service.recordSuccessfulOnlineLogin(
            subject: "demo.user",
            localShortName: "demouser",
            password: "DemoPass123!"
        )

        let response = try handler.handle(
            .verifyOfflineLogin(subject: "demo.user", password: "DemoPass123!")
        )

        XCTAssertEqual(response.localShortName, "demouser")
    }
}
