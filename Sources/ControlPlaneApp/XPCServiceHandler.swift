import Foundation
import ControlPlaneSDK

/// Handles decoded CPRequests from the socket server and returns CPResponses.
/// All methods are async-native; no XPC callback bridging required.
final class RequestHandler {
    private let store:             ProfileStore
    private let rules:             RuleStore
    private let profileActions:    ProfileActionStore
    private let registry:          PluginRegistry
    private let evaluators:        EvaluatorRegistry
    private let actionTypes:       ActionRegistry
    private let sensors:           SensorCoordinator
    private let ruleEngine:        RuleEngine
    private let activationManager: ProfileActivationManager
    private let backend:           Backend

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting     = .sortedKeys
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(
        store:             ProfileStore,
        rules:             RuleStore,
        profileActions:    ProfileActionStore,
        registry:          PluginRegistry,
        evaluators:        EvaluatorRegistry,
        actionTypes:       ActionRegistry,
        sensors:           SensorCoordinator,
        ruleEngine:        RuleEngine,
        activationManager: ProfileActivationManager,
        backend:           Backend
    ) {
        self.store             = store
        self.rules             = rules
        self.profileActions    = profileActions
        self.registry          = registry
        self.evaluators        = evaluators
        self.actionTypes       = actionTypes
        self.sensors           = sensors
        self.ruleEngine        = ruleEngine
        self.activationManager = activationManager
        self.backend           = backend
    }

    // MARK: - Dispatch

    func handle(_ req: CPRequest) async -> CPResponse {
        do {
            let data = try await dispatch(req)
            return CPResponse(id: req.id, data: data)
        } catch {
            return CPResponse(id: req.id, error: error.localizedDescription)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func dispatch(_ req: CPRequest) async throws -> Data? {
        switch req.method {

        // Status
        case "statusGet":             return try await statusGet()

        // Profiles
        case "profileList":           return try await profileList()
        case "profileGet":            return try await profileGet(id: s1(req))
        case "profileCreate":         return try await profileCreate(body: b(req))
        case "profileUpdate":         return try await profileUpdate(id: s1(req), body: b(req))
        case "profileDelete":         try await profileDelete(id: s1(req)); return nil

        // Active profiles
        case "activeProfileList":     return try await activeProfileList()

        // Plugins
        case "pluginList":            return try await pluginList()

        // Sensors
        case "sensorListReadings":    return try await sensorListReadings()
        case "sensorGetReadings":     return try await sensorGetReadings(id: s1(req))
        case "sensorGetOptions":      return try await sensorGetOptions(id: s1(req))
        case "sensorSetOption":
            try await sensorSetOption(id: s1(req), key: s2(req), body: b(req))
            return nil

        // Rules
        case "ruleList":              return try await ruleList()
        case "ruleListForProfile":    return try await ruleListForProfile(profileID: s1(req))
        case "ruleGet":               return try await ruleGet(id: s1(req))
        case "ruleCreate":            return try await ruleCreate(body: b(req))
        case "ruleUpdate":            return try await ruleUpdate(id: s1(req), body: b(req))
        case "ruleDelete":            try await ruleDelete(id: s1(req)); return nil
        case "ruleMatchStatus":       return try await ruleMatchStatus()

        // Profile actions
        case "profileActionList":     return try await profileActionList(profileID: s1(req))
        case "profileActionGet":      return try await profileActionGet(id: s1(req))
        case "profileActionCreate":   return try await profileActionCreate(body: b(req))
        case "profileActionUpdate":   return try await profileActionUpdate(id: s1(req), body: b(req))
        case "profileActionDelete":   try await profileActionDelete(id: s1(req)); return nil
        case "profileActionRun":      return try await profileActionRun(id: s1(req), triggerOverride: req.string2)

        // Action types
        case "actionTypeList":        return try await actionTypeList()

        // Evaluators
        case "evaluatorList":         return try await evaluatorList()

        default:
            throw CPError.invalidData("Unknown method: \(req.method)")
        }
    }

    // Convenience extractors — throw descriptive errors on missing params.
    private func s1(_ req: CPRequest) throws -> String {
        guard let v = req.string1 else { throw CPError.invalidData("Missing string1 for \(req.method)") }
        return v
    }
    private func s2(_ req: CPRequest) throws -> String {
        guard let v = req.string2 else { throw CPError.invalidData("Missing string2 for \(req.method)") }
        return v
    }
    private func b(_ req: CPRequest) throws -> Data {
        guard let v = req.body else { throw CPError.invalidData("Missing body for \(req.method)") }
        return v
    }

    // MARK: - Status

    private func statusGet() async throws -> Data {
        let profileCount  = try await store.list().count
        let ruleCount     = try await rules.list().count
        let pluginCounts  = await registry.counts()
        let evaluatorCount = await evaluators.count()
        let status = BackendStatus(
            pid: ProcessInfo.processInfo.processIdentifier,
            version: "0.1.0",
            startedAt: backend.startedAt,
            profileCount: profileCount,
            ruleCount: ruleCount,
            pluginCounts: BackendStatus.PluginCounts(
                sensors:      pluginCounts.sensors,
                actions:      pluginCounts.actions,
                intelligence: pluginCounts.intelligence,
                evaluators:   evaluatorCount
            )
        )
        return try encoder.encode(status)
    }

    // MARK: - Profiles

    private func profileList() async throws -> Data {
        try encoder.encode(try await store.list())
    }

    private func profileGet(id: String) async throws -> Data {
        try encoder.encode(try await store.get(uuid(id)))
    }

    private func profileCreate(body: Data) async throws -> Data {
        let req = try decoder.decode(ProfileCreateRequest.self, from: body)
        let profile = try await store.create(
            name: req.name,
            parentID: req.parentID,
            exclusive: req.exclusive,
            confidenceThreshold: req.confidenceThreshold
        )
        return try encoder.encode(profile)
    }

    private func profileUpdate(id: String, body: Data) async throws -> Data {
        let req     = try decoder.decode(ProfileUpdateRequest.self, from: body)
        let profile = try await store.update(
            id: uuid(id),
            name: req.name,
            parentID: req.parentID,
            exclusive: req.exclusive,
            confidenceThreshold: req.confidenceThreshold
        )
        return try encoder.encode(profile)
    }

    private func profileDelete(id: String) async throws {
        try await store.delete(uuid(id))
    }

    // MARK: - Active profiles

    private func activeProfileList() async throws -> Data {
        try encoder.encode(await activationManager.currentActive())
    }

    // MARK: - Plugins

    private func pluginList() async throws -> Data {
        try encoder.encode(await registry.list())
    }

    // MARK: - Sensors

    private func sensorListReadings() async throws -> Data {
        await sensors.refreshForQuery()
        return try encoder.encode(await sensors.allSnapshots())
    }

    private func sensorGetReadings(id: String) async throws -> Data {
        await sensors.refreshForQuery()
        guard let snap = await sensors.snapshot(for: id) else {
            throw CPError.invalidData("No sensor loaded with identifier '\(id)'")
        }
        return try encoder.encode(snap)
    }

    private func sensorGetOptions(id: String) async throws -> Data {
        try encoder.encode(try await sensors.getOptions(for: id))
    }

    private func sensorSetOption(id: String, key: String, body: Data) async throws {
        let value = try decoder.decode(SensorOptionValue.self, from: body)
        try await sensors.setOption(for: id, key: key, value: value)
    }

    // MARK: - Rules

    private func ruleList() async throws -> Data {
        try encoder.encode(try await rules.list())
    }

    private func ruleListForProfile(profileID: String) async throws -> Data {
        try encoder.encode(try await rules.list(forProfile: uuid(profileID)))
    }

    private func ruleGet(id: String) async throws -> Data {
        try encoder.encode(try await rules.get(uuid(id)))
    }

    private func ruleCreate(body: Data) async throws -> Data {
        let req  = try decoder.decode(RuleCreateRequest.self, from: body)
        let rule = try await rules.create(
            name:        req.name,
            profileID:   req.profileID,
            sensorID:    req.sensorID,
            readingKey:  req.readingKey,
            operatorID:  req.operatorID,
            comparand:   req.comparand,
            evaluatorID: req.evaluatorID,
            weight:      req.weight,
            negate:      req.negate
        )
        await backend.refreshDynamicSensorKeys()
        return try encoder.encode(rule)
    }

    private func ruleUpdate(id: String, body: Data) async throws -> Data {
        let req  = try decoder.decode(RuleUpdateRequest.self, from: body)
        let rule = try await rules.update(
            id:          uuid(id),
            name:        req.name,
            sensorID:    req.sensorID,
            readingKey:  req.readingKey,
            operatorID:  req.operatorID,
            comparand:   req.comparand,
            evaluatorID: req.evaluatorID,
            weight:      req.weight,
            negate:      req.negate,
            enabled:     req.enabled
        )
        await backend.refreshDynamicSensorKeys()
        return try encoder.encode(rule)
    }

    private func ruleDelete(id: String) async throws {
        try await rules.delete(uuid(id))
        await backend.refreshDynamicSensorKeys()
    }

    private func ruleMatchStatus() async throws -> Data {
        let matches     = await ruleEngine.currentRuleMatches
        let stringKeyed = Dictionary(uniqueKeysWithValues: matches.map { ($0.key.uuidString, $0.value) })
        return try encoder.encode(stringKeyed)
    }

    // MARK: - Profile actions

    private func profileActionList(profileID: String) async throws -> Data {
        try encoder.encode(try await profileActions.list(forProfile: uuid(profileID)))
    }

    private func profileActionGet(id: String) async throws -> Data {
        try encoder.encode(try await profileActions.get(uuid(id)))
    }

    private func profileActionCreate(body: Data) async throws -> Data {
        let req    = try decoder.decode(ProfileActionCreateRequest.self, from: body)
        let action = try await profileActions.create(
            profileID:     req.profileID,
            actionPluginID: req.actionPluginID,
            trigger:       req.trigger,
            config:        req.config
        )
        return try encoder.encode(action)
    }

    private func profileActionUpdate(id: String, body: Data) async throws -> Data {
        let req    = try decoder.decode(ProfileActionUpdateRequest.self, from: body)
        let action = try await profileActions.update(
            id:             uuid(id),
            actionPluginID: req.actionPluginID,
            trigger:        req.trigger,
            config:         req.config,
            enabled:        req.enabled
        )
        return try encoder.encode(action)
    }

    private func profileActionDelete(id: String) async throws {
        try await profileActions.delete(uuid(id))
    }

    /// Execute a stored action immediately, regardless of whether its profile is active.
    /// `triggerOverride` lets the caller specify a trigger; falls back to the action's stored trigger.
    private func profileActionRun(id: String, triggerOverride: String?) async throws -> Data {
        let action = try await profileActions.get(uuid(id))
        let profile = try await store.get(action.profileID)

        let trigger: ActionTrigger
        if let raw = triggerOverride {
            guard let t = ActionTrigger(rawValue: raw) else {
                throw CPError.invalidData("Unknown trigger '\(raw)'. Use: onActivate, onDeactivate")
            }
            trigger = t
        } else {
            trigger = action.trigger
        }

        guard let plugin = await actionTypes.plugin(for: action.actionPluginID) else {
            throw CPError.invalidData("Action plugin '\(action.actionPluginID)' is not loaded")
        }

        try await plugin.execute(trigger: trigger, profile: profile, config: action.config)
        try? await profileActions.recordTriggered(action.id)

        let result = ["status": "ok", "actionID": action.id.uuidString, "trigger": trigger.rawValue]
        return try encoder.encode(result)
    }

    // MARK: - Action types / evaluators

    private func actionTypeList() async throws -> Data {
        try encoder.encode(await actionTypes.list())
    }

    private func evaluatorList() async throws -> Data {
        try encoder.encode(await evaluators.list())
    }

    // MARK: - Helpers

    private func uuid(_ string: String) throws -> UUID {
        guard let uuid = UUID(uuidString: string) else {
            throw CPError.invalidData("'\(string)' is not a valid UUID")
        }
        return uuid
    }
}
