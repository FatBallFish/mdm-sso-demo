import AppKit

@MainActor
public func configurePreLoginWindow(_ window: NSWindow) {
    window.canBecomeVisibleWithoutLogin = true
    window.level = .mainMenu
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    window.isMovable = false
    window.isReleasedWhenClosed = false
}
