import DemoLoginPluginSupport
import Foundation

@MainActor
public final class PreLoginPanelViewModel: ObservableObject {
    public typealias Validator = @Sendable (String, String) async throws -> PreLoginAuthResult

    @Published public var username: String = ""
    @Published public var password: String = ""
    @Published public private(set) var isSubmitting = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var completedResult: PreLoginAuthResult?

    private let validator: Validator

    public init(validator: @escaping Validator) {
        self.validator = validator
    }

    public func submit() async {
        guard !isSubmitting else { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let result = try await validator(username, password)
            switch result {
            case .allow, .userCanceled:
                completedResult = result
            case let .deny(message):
                errorMessage = message
                completedResult = nil
            }
        } catch {
            errorMessage = "Unexpected login error."
            completedResult = nil
        }
    }

    public func cancel() {
        completedResult = .userCanceled
    }
}
