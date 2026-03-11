import CryptoKit
import DemoShared
import Foundation

public protocol AccountSyncing: Sendable {
    func resolveLocalAccount(subject: String) throws -> String?
    func recordSuccessfulOnlineLogin(subject: String, localShortName: String, password: String) throws -> AccountMapping
    func verifyOfflineLogin(subject: String, password: String) throws -> String?
    func bindExistingLocalAccount(subject: String, localShortName: String, password: String) throws -> AccountMapping
    func createLocalAccount(subject: String, suggestedLocalShortName: String, password: String) throws -> AccountMapping
}

public final class AccountSyncService: AccountSyncing, @unchecked Sendable {
    private let store: MappingStore
    private let now: () -> Date

    public init(baseURL: URL, now: @escaping () -> Date = Date.init) {
        self.store = MappingStore(baseURL: baseURL)
        self.now = now
    }

    public func resolveLocalAccount(subject: String) throws -> String? {
        try store.load(subject: subject)?.localShortName
    }

    @discardableResult
    public func recordSuccessfulOnlineLogin(subject: String, localShortName: String, password: String) throws -> AccountMapping {
        let record = AccountMapping(
            ssoSubject: subject,
            localShortName: localShortName,
            lastOnlineAuthAt: now(),
            offlineGraceExpiry: now().addingTimeInterval(TimeInterval(DemoConfiguration.defaultOfflineGraceDays * 24 * 60 * 60)),
            lastTokenRefreshAt: now(),
            lastPasswordFingerprint: Self.fingerprint(password)
        )
        try store.save(record)
        return record
    }

    public func verifyOfflineLogin(subject: String, password: String) throws -> String? {
        guard let record = try store.load(subject: subject) else {
            return nil
        }

        let policy = LoginPolicy(now: now)
        guard policy.isOfflineLoginAllowed(record),
              record.lastPasswordFingerprint == Self.fingerprint(password) else {
            return nil
        }

        return record.localShortName
    }

    public func bindExistingLocalAccount(subject: String, localShortName: String, password: String) throws -> AccountMapping {
        try recordSuccessfulOnlineLogin(subject: subject, localShortName: localShortName, password: password)
    }

    public func createLocalAccount(subject: String, suggestedLocalShortName: String, password: String) throws -> AccountMapping {
        try recordSuccessfulOnlineLogin(subject: subject, localShortName: suggestedLocalShortName, password: password)
    }

    private static func fingerprint(_ password: String) -> String {
        let digest = SHA256.hash(data: Data(password.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
