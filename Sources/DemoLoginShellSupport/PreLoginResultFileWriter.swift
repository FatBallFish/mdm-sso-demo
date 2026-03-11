import DemoLoginPluginSupport
import Foundation
import os

public enum PreLoginResultFileWriter {
    private static let logger = Logger(subsystem: "com.demo.sso.login-plugin", category: "prelogin-shell")

    public static func write(result: PreLoginAuthResult, password: String, to url: URL) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let data = try encoder.encode(PreLoginHelperPayload(result: result, password: password))
        try data.write(to: url, options: .atomic)
        logger.info("pre-login result written path=\(url.path, privacy: .public)")
    }
}
