import AppKit
import Combine
import UserNotifications
import ControlPlaneSDK

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private let backend = Backend()
    private var store: ControlPlaneStore!
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupNotifications()
        setupStatusItem()
        backend.start()

        // Create the observable store and register it as the active-profile observer.
        // The store's setup() calls profileActivationManager.setOnChange, so
        // AppDelegate observes store.$activeProfiles via Combine instead of
        // registering its own callback directly.
        store = ControlPlaneStore(backend: backend)
        store.$activeProfiles
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in self?.rebuildProfileSection(active) }
            .store(in: &cancellables)
        Task { await store.setup() }

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

    @objc private func openPreferences() {
        // NSMenuItem actions are always dispatched on the main thread;
        // wrap in a MainActor Task to satisfy the static isolation check.
        Task { @MainActor in
            PreferencesWindowController.show(store: store)
        }
    }

    private func buildMenu(active: [ActiveProfile]) -> NSMenu {
        let menu = NSMenu()

        let header = NSMenuItem(title: "ControlPlane", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        menu.addItem(.separator())

        menu.addItem(
            NSMenuItem(title: "Preferences…",
                       action: #selector(openPreferences),
                       keyEquivalent: ",")
        )

        // tag 2 marks the separator just before the profile items so
        // rebuildProfileSection can find the right insertion point.
        let profileSeparator = NSMenuItem.separator()
        profileSeparator.tag = 2
        menu.addItem(profileSeparator)

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

        // Find the separator tagged 2 (the one right before the profile items).
        guard let separatorIndex = menu.items.firstIndex(where: { $0.tag == 2 }) else { return }
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
