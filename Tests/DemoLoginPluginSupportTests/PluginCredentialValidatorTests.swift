import DemoShared
import XCTest
@testable import DemoLoginPluginSupport

final class PluginCredentialValidatorTests: XCTestCase {
    func test_returns_http_result_when_health_and_login_succeed() async throws {
        let validator = PluginCredentialValidator(
            remoteIDP: StubRemoteIDP(
                healthResult: .success(()),
                loginResult: .success(.fixture(subject: "demo.user", localShortName: "demouser"))
            ),
            fallbackAuthenticator: DemoAuthenticator(configuration: .seeded)
        )

        let result = try await validator.validate(username: "demo.user", password: "DemoPass123!")

        XCTAssertEqual(result, .allow(localShortName: "demouser", authSource: .http))
    }

    func test_falls_back_when_health_check_fails() async throws {
        let validator = PluginCredentialValidator(
            remoteIDP: StubRemoteIDP(
                healthResult: .failure(DemoAuthError.serviceUnavailable),
                loginResult: .failure(DemoAuthError.invalidCredentials)
            ),
            fallbackAuthenticator: DemoAuthenticator(configuration: .seeded)
        )

        let result = try await validator.validate(username: "demo.user", password: "DemoPass123!")

        XCTAssertEqual(result, .allow(localShortName: "demouser", authSource: .fallback))
    }

    func test_falls_back_when_login_transport_fails() async throws {
        let validator = PluginCredentialValidator(
            remoteIDP: StubRemoteIDP(
                healthResult: .success(()),
                loginResult: .failure(DemoAuthError.serviceUnavailable)
            ),
            fallbackAuthenticator: DemoAuthenticator(configuration: .seeded)
        )

        let result = try await validator.validate(username: "demo.user", password: "DemoPass123!")

        XCTAssertEqual(result, .allow(localShortName: "demouser", authSource: .fallback))
    }

    func test_denies_when_http_and_fallback_both_fail() async throws {
        let validator = PluginCredentialValidator(
            remoteIDP: StubRemoteIDP(
                healthResult: .success(()),
                loginResult: .failure(DemoAuthError.invalidCredentials)
            ),
            fallbackAuthenticator: DemoAuthenticator(configuration: .seeded)
        )

        let result = try await validator.validate(username: "demo.user", password: "wrong")

        XCTAssertEqual(result, .deny(message: "SSO authentication failed."))
    }
}

private struct StubRemoteIDP: PluginRemoteIDPValidating {
    let healthResult: Result<Void, Error>
    let loginResult: Result<DemoTokenResponse, Error>

    func checkHealth() async throws {
        try healthResult.get()
    }

    func login(username: String, password: String) async throws -> DemoTokenResponse {
        try loginResult.get()
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
