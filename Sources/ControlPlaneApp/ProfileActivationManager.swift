import Foundation
import ControlPlaneSDK

/// Tracks which profiles are active across evaluations and executes the
/// actions attached to each profile when it transitions in or out.
actor ProfileActivationManager {
    private var active: [UUID: ActiveProfile] = [:]
    private let linkStore: ProfileActionLinkStore
    private let actionStore: ActionStore
    private let actionRegistry: ActionRegistry
    private let profileStore: ProfileStore

    /// Called (from any thread) whenever the active profile set changes.
    var onActiveProfilesChanged: (@Sendable ([ActiveProfile]) -> Void)?

    init(
        linkStore: ProfileActionLinkStore,
        actionStore: ActionStore,
        actionRegistry: ActionRegistry,
        profileStore: ProfileStore
    ) {
        self.linkStore = linkStore
        self.actionStore = actionStore
        self.actionRegistry = actionRegistry
        self.profileStore = profileStore
    }

    /// Diff new active set against previous; fire attached actions for transitions.
    func update(_ newActive: [ActiveProfile]) async {
        let newIndex = Dictionary(uniqueKeysWithValues: newActive.map { ($0.profile.id, $0) })

        // Compute transitions before any suspension point.
        let activated   = newActive.filter { active[$0.profile.id] == nil }
        let deactivated = active.values.filter { newIndex[$0.profile.id] == nil }

        // Update state NOW — before any await — so re-entrant calls during
        // action execution see the already-updated active set and don't
        // double-fire notifications.
        active = newIndex
        onActiveProfilesChanged?(currentActive())

        // Fire actions after state is committed (suspension points are safe here).
        for ap in activated {
            log("Profile activated: \"\(ap.profile.name)\" (confidence \(String(format: "%.2f", ap.confidence)))", CPLogger.profiles)
            try? await profileStore.recordActivation(ap.profile.id)
            Notifier.profileActivated(ap.profile)
            await runActions(for: ap.profile, trigger: .onActivate)
        }

        for ap in deactivated {
            log("Profile deactivated: \"\(ap.profile.name)\"", CPLogger.profiles)
            try? await profileStore.recordDeactivation(ap.profile.id)
            Notifier.profileDeactivated(ap.profile)
            await runActions(for: ap.profile, trigger: .onDeactivate)
        }
    }

    /// Register a callback invoked whenever the active set changes.
    func setOnChange(_ handler: @escaping @Sendable ([ActiveProfile]) -> Void) {
        onActiveProfilesChanged = handler
    }

    /// Current snapshot for XPC queries.
    func currentActive() -> [ActiveProfile] {
        Array(active.values).sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Private

    private func runActions(for profile: Profile, trigger: ActionTrigger) async {
        let links: [ProfileActionLink]
        do {
            links = try await linkStore.list(forProfile: profile.id)
        } catch {
            logError("Failed to load action links for profile \(profile.id): \(error)", CPLogger.profiles)
            return
        }

        for link in links where link.enabled && link.trigger == trigger {
            let action: Action
            do {
                action = try await actionStore.get(link.actionID)
            } catch {
                logError("Action \(link.actionID) not found for link \(link.id): \(error)", CPLogger.actions)
                continue
            }
            guard action.enabled else { continue }
            guard let plugin = await actionRegistry.plugin(for: action.actionPluginID) else {
                log("Action plugin '\(action.actionPluginID)' not loaded — skipping link \(link.id)", CPLogger.actions)
                continue
            }
            do {
                try await plugin.execute(trigger: trigger, profile: profile, config: action.config)
                try? await linkStore.recordTriggered(link.id)
                log("Action \(action.id) [\(action.actionPluginID)] '\(action.name)' executed for \"\(profile.name)\"", CPLogger.actions)
            } catch {
                logError("Action \(action.id) '\(action.name)' failed: \(error)", CPLogger.actions)
            }
        }
    }
}
