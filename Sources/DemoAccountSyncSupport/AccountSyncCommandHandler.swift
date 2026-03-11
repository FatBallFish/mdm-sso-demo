import Foundation

public struct AccountSyncCommandHandler {
    private let accountSync: AccountSyncing

    public init(accountSync: AccountSyncing) {
        self.accountSync = accountSync
    }

    public func handle(_ command: AccountSyncCommand) throws -> AccountSyncCommandResponse {
        switch command {
        case let .resolveLocalAccount(subject):
            return AccountSyncCommandResponse(localShortName: try accountSync.resolveLocalAccount(subject: subject))
        case let .recordSuccessfulOnlineLogin(subject, localShortName, password):
            let record = try accountSync.recordSuccessfulOnlineLogin(
                subject: subject,
                localShortName: localShortName,
                password: password
            )
            return AccountSyncCommandResponse(localShortName: record.localShortName)
        case let .verifyOfflineLogin(subject, password):
            return AccountSyncCommandResponse(localShortName: try accountSync.verifyOfflineLogin(subject: subject, password: password))
        case let .bindExistingLocalAccount(subject, localShortName, password):
            let record = try accountSync.bindExistingLocalAccount(
                subject: subject,
                localShortName: localShortName,
                password: password
            )
            return AccountSyncCommandResponse(localShortName: record.localShortName)
        case let .createLocalAccount(subject, suggestedLocalShortName, password):
            let record = try accountSync.createLocalAccount(
                subject: subject,
                suggestedLocalShortName: suggestedLocalShortName,
                password: password
            )
            return AccountSyncCommandResponse(localShortName: record.localShortName)
        }
    }
}
