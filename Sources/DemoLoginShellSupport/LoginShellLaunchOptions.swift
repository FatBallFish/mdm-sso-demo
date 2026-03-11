import Foundation

public enum LoginShellLaunchMode: Equatable {
    case interactive
    case plugin(resultFileURL: URL)
}

public struct LoginShellLaunchOptions: Equatable {
    public let mode: LoginShellLaunchMode
    public let idpBaseURL: URL

    public init(mode: LoginShellLaunchMode, idpBaseURL: URL) {
        self.mode = mode
        self.idpBaseURL = idpBaseURL
    }

    public static func parse(arguments: [String]) -> LoginShellLaunchOptions {
        var resultFileURL: URL?
        var idpBaseURL = URL(string: "http://127.0.0.1:48080/")!
        var iterator = arguments.dropFirst().makeIterator()

        while let argument = iterator.next() {
            switch argument {
            case "--plugin-result-file":
                if let value = iterator.next() {
                    resultFileURL = URL(fileURLWithPath: value)
                }
            case "--plugin-idp-base-url":
                if let value = iterator.next(), let url = URL(string: value) {
                    idpBaseURL = url
                }
            default:
                break
            }
        }

        if let resultFileURL {
            return LoginShellLaunchOptions(mode: .plugin(resultFileURL: resultFileURL), idpBaseURL: idpBaseURL)
        }

        return LoginShellLaunchOptions(mode: .interactive, idpBaseURL: idpBaseURL)
    }
}
