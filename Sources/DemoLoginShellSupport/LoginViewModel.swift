import Foundation

public enum LoginShellScreen: Equatable {
    case credentials
    case accountBinding(subject: String)
    case offline(localShortName: String)
    case success(localShortName: String)
    case failure(message: String)
}

public enum LoginShellOutcome: Equatable {
    case success(localShortName: String)
    case needsAccountBinding(subject: String)
    case offlineLogin(localShortName: String)
    case failure(message: String)
}

@MainActor
public final class LoginViewModel: ObservableObject {
    @Published public private(set) var screen: LoginShellScreen
    @Published public var username: String = ""
    @Published public var password: String = ""
    @Published public var networkAvailable: Bool = true
    @Published public var bindingLocalShortName: String = ""
    @Published public private(set) var isSubmitting = false
    @Published public private(set) var pendingSubject: String?

    public init(initialScreen: LoginShellScreen = .credentials) {
        self.screen = initialScreen
    }

    public func handle(_ outcome: LoginShellOutcome) {
        switch outcome {
        case let .success(localShortName):
            pendingSubject = nil
            screen = .success(localShortName: localShortName)
        case let .needsAccountBinding(subject):
            pendingSubject = subject
            if bindingLocalShortName.isEmpty {
                bindingLocalShortName = subject.replacingOccurrences(of: ".", with: "")
            }
            screen = .accountBinding(subject: subject)
        case let .offlineLogin(localShortName):
            pendingSubject = nil
            screen = .offline(localShortName: localShortName)
        case let .failure(message):
            screen = .failure(message: message)
        }
    }

    public func signIn(using coordinator: LoginFlowCoordinator) async {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let outcome = try await coordinator.authenticate(
                username: username,
                password: password,
                networkAvailable: networkAvailable
            )
            handle(outcome)
        } catch {
            handle(.failure(message: "Unexpected login error."))
        }
    }

    public func bindExisting(using coordinator: LoginFlowCoordinator) async {
        guard let pendingSubject else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let outcome = try await coordinator.bindExistingAccount(
                subject: pendingSubject,
                localShortName: bindingLocalShortName,
                password: password
            )
            handle(outcome)
        } catch {
            handle(.failure(message: "Failed to bind local account."))
        }
    }

    public func createLocalAccount(using coordinator: LoginFlowCoordinator) async {
        guard let pendingSubject else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let outcome = try await coordinator.createLocalAccount(
                subject: pendingSubject,
                suggestedLocalShortName: bindingLocalShortName,
                password: password
            )
            handle(outcome)
        } catch {
            handle(.failure(message: "Failed to create local account."))
        }
    }
}
