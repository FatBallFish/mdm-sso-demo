import DemoAccountSyncSupport
import DemoShared
import Foundation

public final class DaemonProcessAccountSyncClient: AccountSyncing, @unchecked Sendable {
    private let daemonExecutableURL: URL
    private let stateRootURL: URL

    public init(daemonExecutableURL: URL, stateRootURL: URL) {
        self.daemonExecutableURL = daemonExecutableURL
        self.stateRootURL = stateRootURL
    }

    public func resolveLocalAccount(subject: String) throws -> String? {
        try execute(.resolveLocalAccount(subject: subject)).localShortName
    }

    public func recordSuccessfulOnlineLogin(subject: String, localShortName: String, password: String) throws -> AccountMapping {
        let response = try execute(
            .recordSuccessfulOnlineLogin(subject: subject, localShortName: localShortName, password: password)
        )
        return makeRecord(subject: subject, localShortName: response.localShortName ?? localShortName)
    }

    public func verifyOfflineLogin(subject: String, password: String) throws -> String? {
        try execute(.verifyOfflineLogin(subject: subject, password: password)).localShortName
    }

    public func bindExistingLocalAccount(subject: String, localShortName: String, password: String) throws -> AccountMapping {
        let response = try execute(
            .bindExistingLocalAccount(subject: subject, localShortName: localShortName, password: password)
        )
        return makeRecord(subject: subject, localShortName: response.localShortName ?? localShortName)
    }

    public func createLocalAccount(subject: String, suggestedLocalShortName: String, password: String) throws -> AccountMapping {
        let response = try execute(
            .createLocalAccount(subject: subject, suggestedLocalShortName: suggestedLocalShortName, password: password)
        )
        return makeRecord(subject: subject, localShortName: response.localShortName ?? suggestedLocalShortName)
    }

    private func execute(_ command: AccountSyncCommand) throws -> AccountSyncCommandResponse {
        let process = Process()
        process.executableURL = daemonExecutableURL
        process.arguments = ["--stdio-json"]

        var environment = ProcessInfo.processInfo.environment
        environment["DEMO_SSO_STATE_ROOT"] = stateRootURL.path
        process.environment = environment

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe

        try process.run()
        let input = try JSONEncoder().encode(command)
        inputPipe.fileHandleForWriting.write(input)
        try inputPipe.fileHandleForWriting.close()

        process.waitUntilExit()
        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let response = try JSONDecoder().decode(AccountSyncCommandResponse.self, from: output)

        if let errorMessage = response.errorMessage {
            throw NSError(domain: "DaemonProcessAccountSyncClient", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        return response
    }

    private func makeRecord(subject: String, localShortName: String) -> AccountMapping {
        AccountMapping(
            ssoSubject: subject,
            localShortName: localShortName,
            lastOnlineAuthAt: .now,
            offlineGraceExpiry: .now.addingTimeInterval(TimeInterval(DemoConfiguration.defaultOfflineGraceDays * 24 * 60 * 60)),
            lastTokenRefreshAt: .now,
            lastPasswordFingerprint: nil
        )
    }
}
