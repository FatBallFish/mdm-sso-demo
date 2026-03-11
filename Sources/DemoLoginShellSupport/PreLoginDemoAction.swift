import Foundation

public enum PreLoginDemoAction: String, Equatable, Sendable {
    case validateSuccess
    case validateFailure

    public var localShortName: String? {
        switch self {
        case .validateSuccess:
            "demouser"
        case .validateFailure:
            nil
        }
    }

    public var password: String {
        switch self {
        case .validateSuccess:
            "DemoPass123!"
        case .validateFailure:
            ""
        }
    }
}
