import XCTest
@testable import DemoLoginShellSupport
import DemoAccountSyncSupport
import DemoShared

final class LoginFlowCoordinatorTests: XCTestCase {
    func test_online_login_returns_success_when_local_mapping_exists() async throws {
        let coordinator = LoginFlowCoordinator(
            idpClient: StubIDPClient(result: .success(.fixture(subject: "demo.user", localShortName: "demouser"))),
            accountSync: StubAccountSyncClient(
                resolvedLocalShortName: "demouser",
                offlineLocalShortName: nil
            )
        )

        let outcome = try await coordinator.authenticate(
            username: "demo.user",
            password: "DemoPass123!",
            networkAvailable: true
        )

        XCTAssertEqual(outcome, LoginShellOutcome.success(localShortName: "demouser"))
    }

    func test_online_login_returns_binding_when_no_local_mapping_exists() async throws {
        let coordinator = LoginFlowCoordinator(
            idpClient: StubIDPClient(result: .success(.fixture(subject: "demo.user", localShortName: "demouser"))),
            accountSync: StubAccountSyncClient(
                resolvedLocalShortName: nil,
                offlineLocalShortName: nil
            )
        )

        let outcome = try await coordinator.authenticate(
            username: "demo.user",
            password: "DemoPass123!",
            networkAvailable: true
        )

        XCTAssertEqual(outcome, LoginShellOutcome.needsAccountBinding(subject: "demo.user"))
    }

    func test_offline_login_returns_cached_local_account() async throws {
        let coordinator = LoginFlowCoordinator(
            idpClient: StubIDPClient(result: .failure(DemoAuthError.invalidCredentials)),
            accountSync: StubAccountSyncClient(
                resolvedLocalShortName: nil,
                offlineLocalShortName: "demouser"
            )
        )

        let outcome = try await coordinator.authenticate(
            username: "demo.user",
            password: "DemoPass123!",
            networkAvailable: false
        )

        XCTAssertEqual(outcome, LoginShellOutcome.offlineLogin(localShortName: "demouser"))
    }

    func test_offline_login_fails_when_no_cached_account_matches() async throws {
        let coordinator = LoginFlowCoordinator(
            idpClient: StubIDPClient(result: .failure(DemoAuthError.invalidCredentials)),
            accountSync: StubAccountSyncClient(
                resolvedLocalShortName: nil,
                offlineLocalShortName: nil
            )
        )

        let outcome = try await coordinator.authenticate(
            username: "demo.user",
            password: "WrongPass123!",
            networkAvailable: false
        )

        XCTAssertEqual(outcome, LoginShellOutcome.failure(message: "Offline login is unavailable."))
    }

    func test_binding_existing_account_returns_success() async throws {
        let coordinator = LoginFlowCoordinator(
            idpClient: StubIDPClient(result: .success(.fixture(subject: "demo.user", localShortName: "demouser"))),
            accountSync: StubAccountSyncClient(
                resolvedLocalShortName: nil,
                offlineLocalShortName: nil
            )
        )

        let outcome = try await coordinator.bindExistingAccount(
            subject: "demo.user",
            localShortName: "existinguser",
            password: "DemoPass123!"
        )

        XCTAssertEqual(outcome, LoginShellOutcome.success(localShortName: "existinguser"))
    }

    func test_creating_local_account_returns_success() async throws {
        let coordinator = LoginFlowCoordinator(
            idpClient: StubIDPClient(result: .success(.fixture(subject: "demo.user", localShortName: "demouser"))),
            accountSync: StubAccountSyncClient(
                resolvedLocalShortName: nil,
                offlineLocalShortName: nil
            )
        )

        let outcome = try await coordinator.createLocalAccount(
            subject: "demo.user",
            suggestedLocalShortName: "demouser",
            password: "DemoPass123!"
        )

        XCTAssertEqual(outcome, LoginShellOutcome.success(localShortName: "demouser"))
    }
}

private struct StubIDPClient: DemoIDPAuthenticating {
    let result: Result<DemoTokenResponse, Error>

    func login(username: String, password: String) async throws -> DemoTokenResponse {
        try result.get()
    }
}

private struct StubAccountSyncClient: AccountSyncing {
    let resolvedLocalShortName: String?
    let offlineLocalShortName: String?

    func resolveLocalAccount(subject: String) throws -> String? {
        resolvedLocalShortName
    }

    func recordSuccessfulOnlineLogin(subject: String, localShortName: String, password: String) throws -> AccountMapping {
        AccountMapping(
            ssoSubject: subject,
            localShortName: localShortName,
            lastOnlineAuthAt: .now,
            offlineGraceExpiry: .now.addingTimeInterval(60),
            lastTokenRefreshAt: .now,
            lastPasswordFingerprint: "cached"
        )
    }

    func verifyOfflineLogin(subject: String, password: String) throws -> String? {
        offlineLocalShortName
    }

    func bindExistingLocalAccount(subject: String, localShortName: String, password: String) throws -> AccountMapping {
        AccountMapping(
            ssoSubject: subject,
            localShortName: localShortName,
            lastOnlineAuthAt: .now,
            offlineGraceExpiry: .now.addingTimeInterval(60),
            lastTokenRefreshAt: .now,
            lastPasswordFingerprint: "cached"
        )
    }

    func createLocalAccount(subject: String, suggestedLocalShortName: String, password: String) throws -> AccountMapping {
        AccountMapping(
            ssoSubject: subject,
            localShortName: suggestedLocalShortName,
            lastOnlineAuthAt: .now,
            offlineGraceExpiry: .now.addingTimeInterval(60),
            lastTokenRefreshAt: .now,
            lastPasswordFingerprint: "cached"
        )
    }
}

private extension DemoTokenResponse {
    static func fixture(subject: String, localShortName: String) -> DemoTokenResponse {
        DemoTokenResponse(
            accessToken: "access",
            refreshToken: "refresh",
            expiresInSeconds: 3600,
            subject: subject,
            localShortName: localShortName
        )
    }
}
