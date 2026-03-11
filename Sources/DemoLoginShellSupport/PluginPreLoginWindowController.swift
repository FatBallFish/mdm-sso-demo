import AppKit
import Combine
import os

@MainActor
public final class PluginPreLoginWindowController: NSWindowController {
    private static let defaultStatusText = "Use the buttons below to verify the plug-in can allow, deny, or return to the native macOS login screen."

    public let statusLabel = NSTextField(labelWithString: defaultStatusText)
    public let successButton = NSButton(title: "Validate Success", target: nil, action: nil)
    public let failureButton = NSButton(title: "Validate Failure", target: nil, action: nil)
    public let cancelButton = NSButton(title: "Back To macOS Login", target: nil, action: nil)

    private let titleLabel = NSTextField(labelWithString: "Demo SSO Sign In")
    private let subtitleLabel = NSTextField(labelWithString: "This pre-login demo avoids text input and verifies that the Authorization plug-in can allow, deny, or return to the native login flow.")
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
        logger.info("appkit pre-login window shown")
    }

    @objc public func validateSuccessPressed(_ sender: Any?) {
        logger.info("pre-login validate success pressed")
        submit(action: .validateSuccess)
    }

    @objc public func validateFailurePressed(_ sender: Any?) {
        logger.info("pre-login validate failure pressed")
        submit(action: .validateFailure)
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
        subtitleLabel.maximumNumberOfLines = 3
        subtitleLabel.lineBreakMode = .byWordWrapping

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.maximumNumberOfLines = 2
        statusLabel.lineBreakMode = .byWordWrapping

        successButton.target = self
        successButton.action = #selector(validateSuccessPressed(_:))
        successButton.keyEquivalent = "\r"

        failureButton.target = self
        failureButton.action = #selector(validateFailurePressed(_:))

        cancelButton.target = self
        cancelButton.action = #selector(cancelPressed(_:))
        cancelButton.keyEquivalent = "\u{1b}"

        let buttonRow = NSStackView(views: [successButton, failureButton, cancelButton])
        buttonRow.orientation = .vertical
        buttonRow.spacing = 12
        buttonRow.alignment = .leading
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        let fieldStack = NSStackView(views: [statusLabel, buttonRow])
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

    private func syncControlState() {
        let isSubmitting = viewModel.isSubmitting

        successButton.isEnabled = !isSubmitting
        failureButton.isEnabled = !isSubmitting
        cancelButton.isEnabled = !isSubmitting
        successButton.title = isSubmitting ? "Validating..." : "Validate Success"

        if let errorMessage = viewModel.errorMessage {
            statusLabel.stringValue = errorMessage
            statusLabel.textColor = .systemRed
        } else if isSubmitting {
            statusLabel.stringValue = "Applying demo validation..."
            statusLabel.textColor = .secondaryLabelColor
        } else {
            statusLabel.stringValue = Self.defaultStatusText
            statusLabel.textColor = .secondaryLabelColor
        }
    }

    private func submit(action: PreLoginDemoAction) {
        syncControlState()

        Task { [weak self, viewModel] in
            await viewModel.submit(action: action)
            await MainActor.run {
                self?.syncControlState()
            }
        }
    }
}
