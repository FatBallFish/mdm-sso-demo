import DemoAccountSyncSupport
import Foundation

func readAllStdin() throws -> Data {
    FileHandle.standardInput.readDataToEndOfFile()
}

let stateRoot = ProcessInfo.processInfo.environment["DEMO_SSO_STATE_ROOT"]
    .map(URL.init(fileURLWithPath:))
    ?? URL(fileURLWithPath: "/Library/Application Support/DemoSSO")

let service = AccountSyncService(baseURL: stateRoot)

if CommandLine.arguments.contains("--stdio-json") {
    let data = try readAllStdin()
    let request = try JSONDecoder().decode(AccountSyncCommand.self, from: data)
    let handler = AccountSyncCommandHandler(accountSync: service)
    let response = try handler.handle(request)
    let encoded = try JSONEncoder().encode(response)
    FileHandle.standardOutput.write(encoded)
} else {
    print("DemoAccountSyncDaemon scaffold ready at \(stateRoot.path)")
    if let mapped = try? service.resolveLocalAccount(subject: "demo.user") {
        print("Existing demo.user mapping: \(mapped)")
    }
}
