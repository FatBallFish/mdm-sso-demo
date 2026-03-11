import DemoAccountSyncSupport
import DemoLoginPluginSupport
import DemoLoginShellSupport
import Foundation

struct BrokerArguments {
    var username: String = ""
    var password: String = ""
    var networkAvailable = true
    var idpBaseURL = URL(string: "http://127.0.0.1:48080/")!
    var daemonExecutableURL: URL?
    var stateRootURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".demo-sso-state")
}

func parseArguments() -> BrokerArguments {
    var parsed = BrokerArguments()
    var iterator = CommandLine.arguments.dropFirst().makeIterator()

    while let argument = iterator.next() {
        switch argument {
        case "--username":
            parsed.username = iterator.next() ?? parsed.username
        case "--password":
            parsed.password = iterator.next() ?? parsed.password
        case "--offline":
            parsed.networkAvailable = false
        case "--idp-base-url":
            if let value = iterator.next(), let url = URL(string: value) {
                parsed.idpBaseURL = url
            }
        case "--daemon":
            if let value = iterator.next() {
                parsed.daemonExecutableURL = URL(fileURLWithPath: value)
            }
        case "--state-root":
            if let value = iterator.next() {
                parsed.stateRootURL = URL(fileURLWithPath: value)
            }
        default:
            break
        }
    }

    return parsed
}

let arguments = parseArguments()
let daemonURL = arguments.daemonExecutableURL
    ?? DemoRuntimeConfiguration.resolveDaemonExecutableURL(
        environment: ProcessInfo.processInfo.environment,
        executablePath: CommandLine.arguments[0],
        currentDirectoryPath: FileManager.default.currentDirectoryPath
    )

let coordinator = LoginFlowCoordinator(
    idpClient: DemoIDPHTTPClient(baseURL: arguments.idpBaseURL),
    accountSync: DaemonProcessAccountSyncClient(
        daemonExecutableURL: daemonURL,
        stateRootURL: arguments.stateRootURL
    )
)

let bridge = LoginPluginBridge()
let outcome = try await coordinator.authenticate(
    username: arguments.username,
    password: arguments.password,
    networkAvailable: arguments.networkAvailable
)
let payload = MechanismDispositionPayload(disposition: bridge.map(result: {
    switch outcome {
    case let .success(localShortName):
        return .success(localShortName: localShortName)
    case let .needsAccountBinding(subject):
        return .needsAccountBinding(subject: subject)
    case let .offlineLogin(localShortName):
        return .offlineAllowed(localShortName: localShortName)
    case let .failure(message):
        return .failure(message: message)
    }
}()))

let data = try JSONEncoder().encode(payload)
FileHandle.standardOutput.write(data)
