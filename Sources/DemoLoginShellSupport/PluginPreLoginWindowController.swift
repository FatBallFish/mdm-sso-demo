import AppKit
import Combine
import os

@MainActor
public final class PluginPreLoginWindowController: NSWindowController, NSTextFieldDelegate {
    private static let defaultStatusText = "The shell first calls the local HTTP IdP. If it is unavailable, the seeded demo credentials are used as fallback."

    public let usernameField = NSTextField(frame: .zero)
    public let passwordField = NSSecureTextField(frame: .zero)
    public let statusLabel = NSTextField(labelWithString: defaultStatusText)
    public let submitButton = NSButton(title: "Sign In", target: nil, action: nil)
    public let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)

    private let titleLabel = NSTextField(labelWithString: "Demo SSO Sign In")
    private let subtitleLabel = NSTextField(labelWithString: "Authenticate with the demo IdP before the native macOS login flow continues.")
    private let viewModel: PreLoginPanelViewModel
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.demo.sso.login-plugin", category: "prelogin-shell")

    public init(viewModel: PreLoginPanelViewModel) {
        self.viewModel = viewModel

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 340),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)

        configurePreLoginWindow(window)
        configureWindow(window)
        bindViewModel()
        syncControlState()
        logger.info("appkit pre-login controller initialized")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeFirstResponder(usernameField)
        logger.info("appkit pre-login window shown")
    }

    public func controlTextDidBeginEditing(_ obj: Notification) {
        if let fieldEditor = obj.userInfo?["NSFieldEditor"] as? NSTextView {
            configureFieldEditor(fieldEditor)
        }
    }

    public func controlTextDidChange(_ obj: Notification) {
        syncViewModelFromFields()
        syncControlState()
    }

    @objc public func submitPressed(_ sender: Any?) {
        logger.info("pre-login submit pressed")
        syncViewModelFromFields()
        syncControlState()

        Task { [viewModel] in
            await viewModel.submit()
        }
    }

    @objc public func cancelPressed(_ sender: Any?) {
        logger.info("pre-login cancel pressed")
        viewModel.cancel()
    }

    private func configureWindow(_ window: NSWindow) {
        window.center()
        window.title = "Demo SSO Pre-Login"
        window.isReleasedWhenClosed = false

        titleLabel.font = .boldSystemFont(ofSize: 28)
        titleLabel.textColor = .labelColor

        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.lineBreakMode = .byWordWrapping

        usernameField.placeholderString = "SSO username"
        usernameField.delegate = self
        configureTextField(usernameField)

        passwordField.placeholderString = "SSO password"
        passwordField.delegate = self
        configureTextField(passwordField)

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.maximumNumberOfLines = 2
        statusLabel.lineBreakMode = .byWordWrapping

        submitButton.target = self
        submitButton.action = #selector(submitPressed(_:))
        submitButton.keyEquivalent = "\r"

        cancelButton.target = self
        cancelButton.action = #selector(cancelPressed(_:))
        cancelButton.keyEquivalent = "\u{1b}"

        let buttonRow = NSStackView(views: [cancelButton, NSView(), submitButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 12
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        let fieldStack = NSStackView(views: [usernameField, passwordField, statusLabel, buttonRow])
        fieldStack.orientation = .vertical
        fieldStack.spacing = 12
        fieldStack.translatesAutoresizingMaskIntoConstraints = false

        let card = NSView(frame: .zero)
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        card.layer?.cornerRadius = 18
        card.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(fieldStack)

        let rootStack = NSStackView(views: [titleLabel, subtitleLabel, card])
        rootStack.orientation = .vertical
        rootStack.spacing = 18
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView(frame: .zero)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rootStack)
        window.contentView = contentView

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),
            rootStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -28),

            card.widthAnchor.constraint(equalToConstant: 560),
            fieldStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            fieldStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            fieldStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            fieldStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])
    }

    private func bindViewModel() {
        viewModel.$isSubmitting
            .combineLatest(viewModel.$errorMessage)
            .sink { [weak self] _, _ in
                self?.syncControlState()
            }
            .store(in: &cancellables)
    }

    private func syncViewModelFromFields() {
        viewModel.username = usernameField.stringValue
        viewModel.password = passwordField.stringValue
    }

    private func syncControlState() {
        let isSubmitting = viewModel.isSubmitting
        let hasCredentials = !usernameField.stringValue.isEmpty && !passwordField.stringValue.isEmpty

        usernameField.isEnabled = !isSubmitting
        passwordField.isEnabled = !isSubmitting
        cancelButton.isEnabled = !isSubmitting
        submitButton.isEnabled = !isSubmitting && hasCredentials
        submitButton.title = isSubmitting ? "Signing In..." : "Sign In"

        if let errorMessage = viewModel.errorMessage {
            statusLabel.stringValue = errorMessage
            statusLabel.textColor = .systemRed
        } else if isSubmitting {
            statusLabel.stringValue = "Authenticating..."
            statusLabel.textColor = .secondaryLabelColor
        } else {
            statusLabel.stringValue = Self.defaultStatusText
            statusLabel.textColor = .secondaryLabelColor
        }
    }

    private func configureTextField(_ textField: NSTextField) {
        textField.isAutomaticTextCompletionEnabled = false
        textField.allowsCharacterPickerTouchBarItem = false
        if #available(macOS 15.2, *) {
            textField.allowsWritingTools = false
        }
    }

    private func configureFieldEditor(_ fieldEditor: NSTextView) {
        fieldEditor.isAutomaticTextCompletionEnabled = false
        fieldEditor.isContinuousSpellCheckingEnabled = false
        fieldEditor.isGrammarCheckingEnabled = false
        fieldEditor.smartInsertDeleteEnabled = false
        fieldEditor.isAutomaticQuoteSubstitutionEnabled = false
        fieldEditor.isAutomaticDashSubstitutionEnabled = false
        fieldEditor.isAutomaticTextReplacementEnabled = false
        fieldEditor.isAutomaticSpellingCorrectionEnabled = false
        fieldEditor.isAutomaticLinkDetectionEnabled = false
        fieldEditor.isAutomaticDataDetectionEnabled = false
        if #available(macOS 15.0, *) {
            fieldEditor.writingToolsBehavior = .none
        }
    }
}
