import DemoLoginPluginSupport
import Foundation

@MainActor
public final class PreLoginPanelViewModel: ObservableObject {
    public typealias Validator = @Sendable (PreLoginDemoAction) async throws -> PreLoginAuthResult

    @Published public private(set) var isSubmitting = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var completedResult: PreLoginAuthResult?
    @Published public private(set) var completedPassword: String = ""

    private let validator: Validator

    public init(validator: @escaping Validator) {
        self.validator = validator
    }

    public func submit(action: PreLoginDemoAction) async {
        guard !isSubmitting else { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let result = try await validator(action)
            switch result {
            case .allow:
                completedResult = result
                completedPassword = action.password
            case .userCanceled:
                completedResult = result
                completedPassword = ""
            case let .deny(message):
                errorMessage = message
                completedResult = nil
                completedPassword = ""
            }
        } catch {
            errorMessage = "Unexpected login error."
            completedResult = nil
            completedPassword = ""
        }
    }

    public func cancel() {
        completedPassword = ""
        completedResult = .userCanceled
    }
}
