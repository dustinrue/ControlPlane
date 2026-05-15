import Foundation
import ControlPlaneSDK

/// Evaluates rules against current sensor snapshots to determine which profiles are active.
///
/// Call `evaluate(snapshots:)` whenever sensor data changes. The engine reads all
/// enabled rules from `RuleStore`, tallies confidence per profile, and compares
/// against each profile's `confidenceThreshold`. Results are cached in
/// `currentActiveProfiles` for cheap XPC queries.
actor RuleEngine {
    private let ruleStore: RuleStore
    private let profileStore: ProfileStore
    private let evaluatorRegistry: EvaluatorRegistry

    private(set) var currentActiveProfiles: [ActiveProfile] = []

    /// Most recent per-rule evaluation result. Keyed by rule UUID.
    /// Populated after each `evaluate(snapshots:)` call.
    private(set) var currentRuleMatches: [UUID: Bool] = [:]

    init(
        ruleStore: RuleStore,
        profileStore: ProfileStore,
        evaluatorRegistry: EvaluatorRegistry
    ) {
        self.ruleStore = ruleStore
        self.profileStore = profileStore
        self.evaluatorRegistry = evaluatorRegistry
    }

    // MARK: - Evaluation

    /// Re-evaluate all rules against the provided snapshots and update `currentActiveProfiles`.
    @discardableResult
    func evaluate(snapshots: [SensorSnapshot]) async throws -> [ActiveProfile] {
        let rules = try await ruleStore.list()
        let profiles = try await profileStore.list()

        // Index snapshots by sensor ID for O(1) lookup.
        let snapshotIndex = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.sensorID, $0) })

        // Accumulate confidence per profile ID, recording each rule's match result.
        var confidence: [UUID: Double] = [:]
        var ruleMatches: [UUID: Bool] = [:]
        for rule in rules where rule.enabled {
            guard let snapshot = snapshotIndex[rule.sensorID] else { continue }
            let reading = snapshot.readings.first(where: { $0.key == rule.readingKey })?.value

            guard let evaluator = await evaluatorRegistry.evaluator(for: rule.evaluatorID) else {
                log("Warning: evaluator '\(rule.evaluatorID)' not found for rule \(rule.id) — skipping")
                continue
            }

            let matched = evaluator.evaluate(reading: reading, operatorID: rule.operatorID, comparand: rule.comparand)
            ruleMatches[rule.id] = matched
            if matched {
                confidence[rule.profileID, default: 0] += rule.weight
            }
        }
        currentRuleMatches = ruleMatches

        // Filter profiles that meet their threshold.
        let profileIndex = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        let active = confidence.compactMap { (profileID, score) -> ActiveProfile? in
            guard let profile = profileIndex[profileID],
                  score >= profile.confidenceThreshold else { return nil }
            return ActiveProfile(profile: profile, confidence: score)
        }.sorted { $0.confidence > $1.confidence }

        currentActiveProfiles = active
        return active
    }
}
