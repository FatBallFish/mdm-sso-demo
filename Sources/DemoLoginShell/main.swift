import AppKit
import Combine
import DemoAccountSyncSupport
import DemoLoginPluginSupport
import DemoLoginShellSupport
import SwiftUI
import os

@MainActor
final class DemoLoginShellAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var pluginWindowController: PluginPreLoginWindowController?
    private var preLoginObserver: AnyCancellable?
    private let launchOptions = LoginShellLaunchOptions.parse(arguments: CommandLine.arguments)
    private let logger = Logger(subsystem: "com.demo.sso.login-plugin", category: "prelogin-shell")

    func applicationDidFinishLaunching(_ notification: Notification) {
        switch launchOptions.mode {
        case .interactive:
            logger.info("launch_mode=interactive")
            launchInteractiveDemo()
        case let .plugin(resultFileURL):
            logger.info("launch_mode=plugin result_file=\(resultFileURL.path, privacy: .public)")
            launchPluginMode(resultFileURL: resultFileURL)
        }
    }

    private func launchInteractiveDemo() {
        let viewModel = LoginViewModel()
        let root = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".demo-sso-state")
        let daemonPath = DemoRuntimeConfiguration.resolveDaemonExecutableURL(
            environment: ProcessInfo.processInfo.environment,
            executablePath: CommandLine.arguments[0],
            currentDirectoryPath: FileManager.default.currentDirectoryPath
        )
        let accountSync = DaemonProcessAccountSyncClient(
            daemonExecutableURL: daemonPath,
            stateRootURL: root
        )
        let idpClient = DemoIDPHTTPClient(baseURL: launchOptions.idpBaseURL)
        let coordinator = LoginFlowCoordinator(idpClient: idpClient, accountSync: accountSync)
        let view = NativeLoginShellView(
            viewModel: viewModel,
            signInAction: {
                await viewModel.signIn(using: coordinator)
            },
            bindAction: {
                await viewModel.bindExisting(using: coordinator)
            },
            createAction: {
                await viewModel.createLocalAccount(using: coordinator)
            }
        )

        showWindow(title: "Demo SSO Login Shell", size: NSSize(width: 560, height: 360), rootView: view)
    }

    private func launchPluginMode(resultFileURL: URL) {
        let validator = PluginCredentialValidator(remoteIDP: DemoIDPHTTPClient(baseURL: launchOptions.idpBaseURL))
        let viewModel = PreLoginPanelViewModel { username, password in
            try await validator.validate(username: username, password: password)
        }

        preLoginObserver = viewModel.$completedResult
            .compactMap { $0 }
            .sink { [weak self, weak viewModel] result in
                guard let self, let viewModel else { return }
                self.finishPluginMode(result: result, password: viewModel.password, resultFileURL: resultFileURL)
            }

        let controller = PluginPreLoginWindowController(viewModel: viewModel)
        pluginWindowController = controller
        controller.showWindow(nil)
        window = controller.window
    }

    private func finishPluginMode(result: PreLoginAuthResult, password: String, resultFileURL: URL) {
        do {
            logger.info("plugin_mode_complete action=\(String(describing: result), privacy: .public)")
            try PreLoginResultFileWriter.write(result: result, password: password, to: resultFileURL)
            NSApp.terminate(nil)
        } catch {
            fputs("Failed to write pre-login result: \(error)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }

    private func showWindow<Content: View>(title: String, size: NSSize, rootView: Content) {
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        configurePreLoginWindow(window)
        window.center()
        window.title = title
        window.contentViewController = hostingController
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        self.window = window
    }
}

let app = NSApplication.shared
let delegate = DemoLoginShellAppDelegate()
app.setActivationPolicy(.regular)
app.delegate = delegate
app.activate(ignoringOtherApps: true)
app.run()
