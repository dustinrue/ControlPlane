import AppKit
import SwiftUI

/// Manages the single Preferences window. Call `show(store:onOpen:onClose:)` from
/// any context — it opens the window if not already visible, or brings it to front
/// if it is.  `onOpen` fires when the window first becomes visible; `onClose` fires
/// when the user dismisses it.
@MainActor
final class PreferencesWindowController: NSWindowController, NSWindowDelegate {

    private static var shared: PreferencesWindowController?

    /// Called the first time the window is shown (not on subsequent bringToFront calls).
    var onOpen: (() -> Void)?
    /// Called when the window is closed.
    var onClose: (() -> Void)?

    static func show(
        store: ControlPlaneStore,
        onOpen: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        if shared == nil {
            let hostingController = NSHostingController(rootView: PreferencesView(store: store))
            let window = NSWindow(contentViewController: hostingController)
            window.title = "ControlPlane"
            window.setContentSize(NSSize(width: 900, height: 620))
            window.minSize = NSSize(width: 700, height: 450)
            window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            window.center()
            window.isReleasedWhenClosed = false

            let controller = PreferencesWindowController(window: window)
            controller.onOpen = onOpen
            controller.onClose = onClose
            window.delegate = controller
            shared = controller

            // Fire onOpen the first time the window is created and shown.
            onOpen?()
        }

        shared?.showWindow(nil)
        shared?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        onClose?()
        PreferencesWindowController.shared = nil
    }
}
