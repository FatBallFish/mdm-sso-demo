import Foundation

public enum DemoRuntimeConfiguration {
    public static func resolveDaemonExecutableURL(
        environment: [String: String],
        executablePath: String,
        currentDirectoryPath: String,
        fileExists: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) -> URL {
        if let explicit = environment["DEMO_ACCOUNTSYNC_DAEMON_PATH"], !explicit.isEmpty {
            return URL(fileURLWithPath: explicit)
        }

        let executableURL = URL(fileURLWithPath: executablePath)
        let siblingURL = executableURL.deletingLastPathComponent().appendingPathComponent("DemoAccountSyncDaemon")
        if fileExists(siblingURL.path) {
            return siblingURL
        }

        return URL(fileURLWithPath: currentDirectoryPath)
            .appendingPathComponent(".build/arm64-apple-macosx/debug/DemoAccountSyncDaemon")
    }
}
