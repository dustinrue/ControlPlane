import Foundation
import Combine
import ControlPlaneSDK

/// Observable data model that bridges the actor-based backend to SwiftUI.
///
/// All mutations happen on the MainActor; async backend calls are dispatched
/// from there and results are written back on the main thread.
@MainActor
final class ControlPlaneStore: ObservableObject {

    // MARK: - Published state

    @Published var profiles: [Profile] = []
    @Published var rules: [Rule] = []
    @Published var profileActions: [ProfileAction] = []
    @Published var snapshots: [SensorSnapshot] = []
    @Published var actionTypes: [ActionTypeInfo] = []
    @Published var operators: [OperatorDescriptor] = []
    @Published var activeProfiles: [ActiveProfile] = []
    @Published var errorMessage: String?

    /// Most recent per-rule match state from the last rule engine evaluation.
    /// Keyed by rule UUID. Only contains entries for enabled rules.
    @Published var ruleMatches: [UUID: Bool] = [:]

    /// Current confidence score for every profile, including those below their threshold.
    /// Profiles with no matching rules have a score of 0.0.
    @Published var profileConfidences: [UUID: Double] = [:]

    /// IDs of sensors that are DynamicKeySensor — their reading keys come from
    /// rules rather than from the snapshot, so the UI must let the user type a key.
    @Published var dynamicSensorIDs: Set<String> = []

    // MARK: - Internal

    let backend: Backend
    private var snapshotRefreshTask: Task<Void, Never>?

    // MARK: - Init

    init(backend: Backend) {
        self.backend = backend
    }

    // MARK: - Setup

    /// Wire callbacks and load initial data. Call once after the backend has started.
    func setup() async {
        // Register for active-profile change notifications.
        // This replaces any previous setOnChange handler (e.g. the one used
        // by AppDelegate to rebuild the menu — AppDelegate now observes
        // store.$activeProfiles via Combine instead).
        await backend.profileActivationManager.setOnChange { [weak self] active in
            Task { @MainActor [weak self] in
                self?.activeProfiles = active
            }
        }

        // Register for rule-engine evaluation results so the UI can show live
        // per-rule match state and per-profile confidence scores in real time.
        await backend.ruleEngine.setOnEvaluated { [weak self] matches, confidences in
            Task { @MainActor [weak self] in
                self?.ruleMatches = matches
                self?.profileConfidences = confidences
            }
        }

        await refresh()
        startSnapshotRefresh()
    }

    // MARK: - Data refresh

    /// Reload all data from the backend.
    func refresh() async {
        do { profiles = try await backend.profileStore.list() }
        catch { errorMessage = error.localizedDescription }

        do { rules = try await backend.ruleStore.list() }
        catch { errorMessage = error.localizedDescription }

        actionTypes = await backend.actionRegistry.list()

        let evals = await backend.evaluatorRegistry.list()
        operators = evals.flatMap { $0.operators }

        let dynIDs = await backend.sensorCoordinator.dynamicSensorIDs()
        dynamicSensorIDs = Set(dynIDs)

        await refreshSnapshots()
        await refreshProfileActions()
    }

    func refreshSnapshots() async {
        snapshots = await backend.sensorCoordinator.allSnapshots()
    }

    func refreshProfileActions() async {
        do {
            var all: [ProfileAction] = []
            for p in profiles {
                let actions = try await backend.profileActionStore.list(forProfile: p.id)
                all += actions
            }
            profileActions = all
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Poll sensor snapshots every 2 s so the Sensors tab stays live.
    private func startSnapshotRefresh() {
        snapshotRefreshTask?.cancel()
        snapshotRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                await self?.refreshSnapshots()
            }
        }
    }

    // MARK: - Profile CRUD

    func createProfile(name: String, confidenceThreshold: Double = 1.0, exclusive: Bool = false) async {
        do {
            let p = try await backend.profileStore.create(
                name: name, parentID: nil,
                exclusive: exclusive,
                confidenceThreshold: confidenceThreshold
            )
            profiles.append(p)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateProfile(
        _ profile: Profile,
        name: String,
        confidenceThreshold: Double,
        exclusive: Bool
    ) async {
        do {
            let updated = try await backend.profileStore.update(
                id: profile.id, name: name, parentID: profile.parentID,
                exclusive: exclusive, confidenceThreshold: confidenceThreshold
            )
            if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
                profiles[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteProfile(_ profile: Profile) async {
        do {
            try await backend.profileStore.delete(profile.id)
            profiles.removeAll { $0.id == profile.id }
            rules.removeAll { $0.profileID == profile.id }
            profileActions.removeAll { $0.profileID == profile.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Rule CRUD

    func createRule(
        name: String,
        profileID: UUID,
        sensorID: String,
        readingKey: String,
        operatorID: String,
        comparand: ObservationValue,
        weight: Double = 1.0,
        negate: Bool = false
    ) async {
        do {
            let r = try await backend.ruleStore.create(
                name: name, profileID: profileID, sensorID: sensorID,
                readingKey: readingKey, operatorID: operatorID, comparand: comparand,
                weight: weight, negate: negate
            )
            rules.append(r)
            await backend.refreshDynamicSensorKeys()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateRule(
        _ rule: Rule,
        name: String,
        sensorID: String,
        readingKey: String,
        operatorID: String,
        comparand: ObservationValue,
        weight: Double,
        negate: Bool,
        enabled: Bool
    ) async {
        do {
            let updated = try await backend.ruleStore.update(
                id: rule.id, name: name, sensorID: sensorID,
                readingKey: readingKey, operatorID: operatorID, comparand: comparand,
                evaluatorID: rule.evaluatorID, weight: weight, negate: negate, enabled: enabled
            )
            if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
                rules[idx] = updated
            }
            await backend.refreshDynamicSensorKeys()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteRule(_ rule: Rule) async {
        do {
            try await backend.ruleStore.delete(rule.id)
            rules.removeAll { $0.id == rule.id }
            await backend.refreshDynamicSensorKeys()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setRuleEnabled(_ rule: Rule, enabled: Bool) async {
        do {
            let updated = try await backend.ruleStore.update(
                id: rule.id, name: rule.name, sensorID: rule.sensorID,
                readingKey: rule.readingKey, operatorID: rule.operatorID,
                comparand: rule.comparand, evaluatorID: rule.evaluatorID,
                weight: rule.weight, negate: rule.negate, enabled: enabled
            )
            if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
                rules[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - ProfileAction CRUD

    func createProfileAction(
        profileID: UUID,
        actionPluginID: String,
        trigger: ActionTrigger,
        config: [String: String]
    ) async {
        do {
            let a = try await backend.profileActionStore.create(
                profileID: profileID, actionPluginID: actionPluginID,
                trigger: trigger, config: config
            )
            profileActions.append(a)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteProfileAction(_ action: ProfileAction) async {
        do {
            try await backend.profileActionStore.delete(action.id)
            profileActions.removeAll { $0.id == action.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setProfileActionEnabled(_ action: ProfileAction, enabled: Bool) async {
        do {
            let updated = try await backend.profileActionStore.update(
                id: action.id, actionPluginID: action.actionPluginID,
                trigger: action.trigger, config: action.config, enabled: enabled
            )
            if let idx = profileActions.firstIndex(where: { $0.id == action.id }) {
                profileActions[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Derived helpers

    func rules(for profileID: UUID) -> [Rule] {
        rules.filter { $0.profileID == profileID }.sorted { $0.createdAt < $1.createdAt }
    }

    func actions(for profileID: UUID) -> [ProfileAction] {
        profileActions.filter { $0.profileID == profileID }.sorted { $0.createdAt < $1.createdAt }
    }

    func isActive(_ profileID: UUID) -> Bool {
        activeProfiles.contains { $0.profile.id == profileID }
    }

    func confidence(for profileID: UUID) -> Double? {
        activeProfiles.first { $0.profile.id == profileID }?.confidence
    }

    /// Current combined confidence for a profile, even if it is below its activation
    /// threshold. Returns 0.0 before the first rule evaluation or when no rules match.
    func currentConfidence(for profileID: UUID) -> Double {
        profileConfidences[profileID] ?? 0.0
    }

    func actionType(for id: String) -> ActionTypeInfo? {
        actionTypes.first { $0.id == id }
    }

    func snapshot(for sensorID: String) -> SensorSnapshot? {
        snapshots.first { $0.sensorID == sensorID }
    }

    /// The `type` string for an ObservationValue ("string", "boolean", "number", "strings").
    func valueType(_ value: ObservationValue) -> String {
        switch value {
        case .string:  return "string"
        case .boolean: return "boolean"
        case .number:  return "number"
        case .strings: return "strings"
        }
    }

    /// Operators that accept a given value type.
    func operators(for valueType: String) -> [OperatorDescriptor] {
        operators.filter { $0.applicableTypes.contains(valueType) }
    }
}
