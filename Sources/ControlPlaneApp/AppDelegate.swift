import AppKit
import UserNotifications
import ControlPlaneSDK

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private let backend = Backend()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupNotifications()
        setupStatusItem()
        backend.start()
        observeActiveProfiles()
        CpctlInstaller.installIfNeeded()
    }

    // MARK: - Notifications

    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()

        // Delegate must be set before any notification is delivered.
        center.delegate = self

        // Discard any notifications that were queued by a previous instance
        // but not yet delivered (e.g. time-triggered notifications left over
        // from a crash or rapid restart during development).
        center.removeAllPendingNotificationRequests()

        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error { log("Notification authorization error: \(error)") }
            log("Notification permission: \(granted ? "granted" : "denied")")
            if granted {
                Notifier.startup()
            }
        }
    }

    // MARK: - Active profile observation

    private func observeActiveProfiles() {
        Task {
            await backend.profileActivationManager.setOnChange { [weak self] active in
                DispatchQueue.main.async { self?.rebuildProfileSection(active) }
            }
        }
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }

        // Use the "airplane" SF Symbol as a template image — it renders in monochrome,
        // scales to any menu-bar size, and adapts to dark/light mode automatically.
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        if let image = NSImage(systemSymbolName: "airplane", accessibilityDescription: "ControlPlane")?
                           .withSymbolConfiguration(config) {
            button.image = image
        }

        button.setAccessibilityLabel("ControlPlane")
        statusItem?.menu = buildMenu(active: [])
    }

    private func buildMenu(active: [ActiveProfile]) -> NSMenu {
        let menu = NSMenu()

        let header = NSMenuItem(title: "ControlPlane", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        menu.addItem(.separator())

        if active.isEmpty {
            let item = NSMenuItem(title: "No active profile", action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.tag = 1
            menu.addItem(item)
        } else {
            for ap in active {
                let item = NSMenuItem(title: ap.profile.name, action: nil, keyEquivalent: "")
                item.isEnabled = false
                item.tag = 1
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        menu.addItem(
            NSMenuItem(title: "Quit ControlPlane",
                       action: #selector(NSApplication.terminate(_:)),
                       keyEquivalent: "q")
        )
        return menu
    }

    private func rebuildProfileSection(_ active: [ActiveProfile]) {
        guard let menu = statusItem?.menu else { return }

        menu.items.filter { $0.tag == 1 }.forEach { menu.removeItem($0) }

        guard let separatorIndex = menu.items.firstIndex(where: { $0.isSeparatorItem }) else { return }
        let insertAt = separatorIndex + 1

        if active.isEmpty {
            let item = NSMenuItem(title: "No active profile", action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.tag = 1
            menu.insertItem(item, at: insertAt)
        } else {
            for (offset, ap) in active.enumerated() {
                let item = NSMenuItem(title: ap.profile.name, action: nil, keyEquivalent: "")
                item.isEnabled = false
                item.tag = 1
                menu.insertItem(item, at: insertAt + offset)
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Called when a notification is about to be presented while the app is running.
    /// Returning .banner + .sound ensures the banner pops up even in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
