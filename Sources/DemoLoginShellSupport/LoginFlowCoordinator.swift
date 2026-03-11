import DemoAccountSyncSupport
import DemoShared
import Foundation

public struct LoginFlowCoordinator: Sendable {
    private let idpClient: DemoIDPAuthenticating
    private let accountSync: AccountSyncing

    public init(idpClient: DemoIDPAuthenticating, accountSync: AccountSyncing) {
        self.idpClient = idpClient
        self.accountSync = accountSync
    }

    public func authenticate(username: String, password: String, networkAvailable: Bool) async throws -> LoginShellOutcome {
        if networkAvailable {
            let token: DemoTokenResponse
            do {
                token = try await idpClient.login(username: username, password: password)
            } catch {
                return .failure(message: "SSO authentication failed.")
            }

            do {
                if let localShortName = try accountSync.resolveLocalAccount(subject: token.subject) {
                    _ = try accountSync.recordSuccessfulOnlineLogin(
                        subject: token.subject,
                        localShortName: localShortName,
                        password: password
                    )
                    return .success(localShortName: localShortName)
                }

                return .needsAccountBinding(subject: token.subject)
            } catch {
                return .failure(message: "Local account sync service failed.")
            }
        }

        if let localShortName = try accountSync.verifyOfflineLogin(subject: username, password: password) {
            return .offlineLogin(localShortName: localShortName)
        }

        return .failure(message: "Offline login is unavailable.")
    }

    public func bindExistingAccount(subject: String, localShortName: String, password: String) async throws -> LoginShellOutcome {
        let record = try accountSync.bindExistingLocalAccount(
            subject: subject,
            localShortName: localShortName,
            password: password
        )
        return .success(localShortName: record.localShortName)
    }

    public func createLocalAccount(subject: String, suggestedLocalShortName: String, password: String) async throws -> LoginShellOutcome {
        let record = try accountSync.createLocalAccount(
            subject: subject,
            suggestedLocalShortName: suggestedLocalShortName,
            password: password
        )
        return .success(localShortName: record.localShortName)
    }
}
