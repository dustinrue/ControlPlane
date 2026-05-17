import AppKit
import Combine
import UserNotifications
import ControlPlaneSDK

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private let backend = Backend()
    private var store: ControlPlaneStore!
    private var cancellables = Set<AnyCancellable>()

    /// Kept so we can refresh its submenu without rebuilding the whole menu.
    private var runActionsMenuItem: NSMenuItem?

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

        // Rebuild the Run Actions submenu whenever actions, profiles, or action types change.
        store.$profileActions
            .combineLatest(store.$profiles, store.$actionTypes)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuildRunActionsMenu() }
            .store(in: &cancellables)

        Task { await store.setup() }

        CpctlInstaller.installIfNeeded()
    }

    // MARK: - Notifications

    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.removeAllPendingNotificationRequests()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error { logError("Notification authorization error: \(error)", CPLogger.setup) }
            log("Notification permission: \(granted ? "granted" : "denied")", CPLogger.setup)
            if granted { Notifier.startup() }
        }
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }

        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        if let image = NSImage(systemSymbolName: "airplane", accessibilityDescription: "ControlPlane")?
                           .withSymbolConfiguration(config) {
            button.image = image
            button.imagePosition = .imageLeft
        }

        button.setAccessibilityLabel("ControlPlane")
        statusItem?.menu = buildMenu(active: [])
    }

    private func updateStatusTitle(_ active: [ActiveProfile]) {
        guard let button = statusItem?.button else { return }
        button.title = active.isEmpty ? "" : " " + active.map(\.profile.name).joined(separator: ", ")
    }

    // MARK: - Menu construction

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

        // Run Actions flyout — submenu is populated by rebuildRunActionsMenu().
        let runItem = NSMenuItem(title: "Run Action", action: nil, keyEquivalent: "")
        runItem.submenu = NSMenu(title: "Run Action")
        runActionsMenuItem = runItem
        menu.addItem(runItem)

        // tag 2 — anchor for rebuildProfileSection insertion.
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

    // MARK: - Run Actions submenu

    private func rebuildRunActionsMenu() {
        guard let submenu = runActionsMenuItem?.submenu else { return }
        submenu.removeAllItems()

        // Sort by profile name, then by creation date within a profile.
        let actions = store.profileActions.sorted { a, b in
            let nameA = store.profiles.first { $0.id == a.profileID }?.name ?? ""
            let nameB = store.profiles.first { $0.id == b.profileID }?.name ?? ""
            return nameA == nameB ? a.createdAt < b.createdAt : nameA < nameB
        }

        if actions.isEmpty {
            let empty = NSMenuItem(title: "No actions configured", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
            return
        }

        // Group by profile with a section header for each.
        var lastProfileID: UUID? = nil
        for action in actions {
            let profileName = store.profiles.first { $0.id == action.profileID }?.name ?? "Unknown Profile"
            let typeName    = store.actionType(for: action.actionPluginID)?.displayName ?? action.actionPluginID
            let trigger     = action.trigger == ActionTrigger.onActivate ? "activate" : "deactivate"

            if action.profileID != lastProfileID {
                if lastProfileID != nil { submenu.addItem(.separator()) }
                let header = NSMenuItem(title: profileName, action: nil, keyEquivalent: "")
                header.isEnabled = false
                submenu.addItem(header)
                lastProfileID = action.profileID
            }

            let title = "  \(typeName) (\(trigger))"
            let item = NSMenuItem(title: title, action: #selector(runActionItem(_:)), keyEquivalent: "")
            item.representedObject = action
            item.target = self
            if !action.enabled {
                item.isEnabled = false
                item.title = title + " [disabled]"
            }
            submenu.addItem(item)
        }
    }

    @objc private func runActionItem(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? ProfileAction else { return }
        // Access @MainActor-isolated store on the main actor, then hop to a plain
        // Task for the async plugin execution.
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let profile = self.store.profiles.first(where: { $0.id == action.profileID }) else {
                log("Run Action: profile \(action.profileID) not found", CPLogger.actions)
                return
            }
            guard let plugin = await self.backend.actionRegistry.plugin(for: action.actionPluginID) else {
                log("Run Action: plugin '\(action.actionPluginID)' not loaded", CPLogger.actions)
                return
            }
            do {
                log("Run Action: executing \(action.actionPluginID) [\(action.trigger.rawValue)] for \"\(profile.name)\"", CPLogger.actions)
                try await plugin.execute(trigger: action.trigger, profile: profile, config: action.config)
                log("Run Action: done", CPLogger.actions)
            } catch {
                logError("Run Action failed: \(error)", CPLogger.actions)
            }
        }
    }

    // MARK: - Profile section

    private func rebuildProfileSection(_ active: [ActiveProfile]) {
        updateStatusTitle(active)

        guard let menu = statusItem?.menu else { return }

        menu.items.filter { $0.tag == 1 }.forEach { menu.removeItem($0) }

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

    // MARK: - Actions

    @objc private func openPreferences() {
        Task { @MainActor in
            PreferencesWindowController.show(store: store)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
