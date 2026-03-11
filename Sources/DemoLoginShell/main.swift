import AppKit
import DemoAccountSyncSupport
import DemoLoginShellSupport
import SwiftUI

final class DemoLoginShellAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let viewModel = LoginViewModel()
        let root = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".demo-sso-state")
        let daemonPath = ProcessInfo.processInfo.environment["DEMO_ACCOUNTSYNC_DAEMON_PATH"]
            .map(URL.init(fileURLWithPath:))
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(".build/arm64-apple-macosx/debug/DemoAccountSyncDaemon")
        let accountSync = DaemonProcessAccountSyncClient(
            daemonExecutableURL: daemonPath,
            stateRootURL: root
        )
        let idpClient = DemoIDPHTTPClient(baseURL: URL(string: "http://127.0.0.1:48080/")!)
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
        let hostingController = NSHostingController(rootView: view)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 360),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Demo SSO Login Shell"
        window.contentViewController = hostingController
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }
}

let app = NSApplication.shared
let delegate = DemoLoginShellAppDelegate()
app.setActivationPolicy(.regular)
app.delegate = delegate
app.activate(ignoringOtherApps: true)
app.run()
