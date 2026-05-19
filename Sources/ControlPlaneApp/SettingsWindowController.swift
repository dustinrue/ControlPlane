import AppKit
import SwiftUI

/// Manages the single Settings window. Call `show(store:onOpen:onClose:)` from
/// any context — it opens the window if not already visible, or brings it to
/// front if it is.  `onOpen` fires when the window first becomes visible;
/// `onClose` fires when the user dismisses it.
///
/// ## Dock icon / Cmd+Tab behaviour
///
/// ControlPlane is a menu-bar-only app (`LSUIElement = true`), so it has no
/// Dock presence by default. While the Settings window is open the activation
/// policy is switched to `.regular` so the app appears in the Dock and the
/// Cmd+Tab switcher, making it easy to bring the window back to front. When
/// the window closes the policy reverts to `.accessory`.
@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    private static var shared: SettingsWindowController?

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
            let hostingController = NSHostingController(rootView: SettingsView(store: store))
            let window = NSWindow(contentViewController: hostingController)
            window.title = "ControlPlane Settings"
            window.setContentSize(NSSize(width: 900, height: 620))
            window.minSize = NSSize(width: 700, height: 450)
            window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            window.center()
            window.isReleasedWhenClosed = false

            let controller = SettingsWindowController(window: window)
            controller.onOpen = onOpen
            controller.onClose = onClose
            window.delegate = controller
            shared = controller

            // Fire onOpen the first time the window is created and shown.
            onOpen?()
        }

        // Switch to regular policy BEFORE making the window key so the Dock
        // icon and Cmd+Tab entry are present from the first visible frame.
        NSApp.setActivationPolicy(.regular)
        shared?.showWindow(nil)
        shared?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        onClose?()
        SettingsWindowController.shared = nil
        // Revert to menu-bar-only once the Settings window is gone.
        NSApp.setActivationPolicy(.accessory)
    }
}
