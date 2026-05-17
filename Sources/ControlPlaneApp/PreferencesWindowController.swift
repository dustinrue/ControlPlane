import AppKit
import SwiftUI

/// Manages the single Preferences window. Call `show(store:)` from any context —
/// it opens the window if not already visible, or brings it to front if it is.
@MainActor
final class PreferencesWindowController: NSWindowController, NSWindowDelegate {

    private static var shared: PreferencesWindowController?

    static func show(store: ControlPlaneStore) {
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
            window.delegate = controller
            shared = controller
        }

        shared?.showWindow(nil)
        shared?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        PreferencesWindowController.shared = nil
    }
}
