import XCTest
@testable import DemoAccountSyncSupport

final class AccountSyncServiceTests: XCTestCase {
    func test_successful_online_login_persists_mapping_and_password_fingerprint() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = AccountSyncService(baseURL: tempDir)

        let record = try service.recordSuccessfulOnlineLogin(
            subject: "demo.user",
            localShortName: "demouser",
            password: "DemoPass123!"
        )

        XCTAssertEqual(record.localShortName, "demouser")
        XCTAssertNotNil(record.lastPasswordFingerprint)
        XCTAssertEqual(try service.resolveLocalAccount(subject: "demo.user"), "demouser")
    }

    func test_offline_login_succeeds_within_grace_for_matching_cached_password() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = AccountSyncService(baseURL: tempDir, now: { Date(timeIntervalSince1970: 1_000) })
        _ = try service.recordSuccessfulOnlineLogin(
            subject: "demo.user",
            localShortName: "demouser",
            password: "DemoPass123!"
        )

        let result = try service.verifyOfflineLogin(subject: "demo.user", password: "DemoPass123!")

        XCTAssertEqual(result, "demouser")
    }

    func test_offline_login_fails_when_password_differs() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = AccountSyncService(baseURL: tempDir, now: { Date(timeIntervalSince1970: 1_000) })
        _ = try service.recordSuccessfulOnlineLogin(
            subject: "demo.user",
            localShortName: "demouser",
            password: "DemoPass123!"
        )

        let result = try service.verifyOfflineLogin(subject: "demo.user", password: "WrongPass123!")

        XCTAssertNil(result)
    }

    func test_bind_existing_local_account_persists_selected_short_name() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = AccountSyncService(baseURL: tempDir)

        let record = try service.bindExistingLocalAccount(
            subject: "demo.user",
            localShortName: "existinguser",
            password: "DemoPass123!"
        )

        XCTAssertEqual(record.localShortName, "existinguser")
        XCTAssertEqual(try service.resolveLocalAccount(subject: "demo.user"), "existinguser")
    }

    func test_create_local_account_uses_suggested_short_name_when_provided() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = AccountSyncService(baseURL: tempDir)

        let record = try service.createLocalAccount(
            subject: "demo.user",
            suggestedLocalShortName: "demouser",
            password: "DemoPass123!"
        )

        XCTAssertEqual(record.localShortName, "demouser")
    }
}
