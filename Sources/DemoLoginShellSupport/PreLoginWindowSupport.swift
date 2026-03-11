import AppKit

@MainActor
public func configurePreLoginApplication(_ application: NSApplication = .shared) {
    application.disableRelaunchOnLogin()
    NSWindow.allowsAutomaticWindowTabbing = false
}

@MainActor
public func configurePreLoginWindow(_ window: NSWindow) {
    window.canBecomeVisibleWithoutLogin = true
    window.level = .mainMenu
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    window.isMovable = false
    window.isReleasedWhenClosed = false
    window.isRestorable = false
}
