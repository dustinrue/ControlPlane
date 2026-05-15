import Foundation

// MARK: - Operator descriptor

/// Describes one comparison operator an evaluator plugin supports.
/// Used by the UI and cpctl to populate operator choices.
public struct OperatorDescriptor: Codable, Sendable, Equatable {
    /// Machine identifier used in Rule.operatorID, e.g. "equals".
    public let id: String
    /// Short human label shown in the UI, e.g. "=".
    public let label: String
    /// Types this operator accepts: "string", "boolean", "number", "strings".
    public let applicableTypes: [String]

    public init(id: String, label: String, applicableTypes: [String]) {
        self.id = id
        self.label = label
        self.applicableTypes = applicableTypes
    }
}

// MARK: - Evaluator plugin

/// A plugin that evaluates rule conditions.
///
/// The default bundled evaluator handles standard comparisons (=, !=, >, <, etc.).
/// Third-party evaluators (e.g. AI-based) can be loaded as plugins and referenced
/// by ID in individual rules.
///
/// Evaluation is synchronous. AI-based evaluators should use cached/pre-computed results.
public protocol EvaluatorPlugin: ControlPlanePlugin {
    /// Returns true if `reading` satisfies `operatorID` against `comparand`.
    /// `reading` is nil when the sensor has no value for the rule's readingKey.
    func evaluate(
        reading: ObservationValue?,
        operatorID: String,
        comparand: ObservationValue
    ) -> Bool

    /// All operators this evaluator can handle.
    func supportedOperators() -> [OperatorDescriptor]
}

// MARK: - Rule

/// A single condition that contributes confidence toward activating a profile.
///
/// Confidence is combined across rules using a multiplicative inverse (unconfidence) model:
///
///     unconfidence = ∏(1 − weight)  for each matching rule
///     profile confidence = 1 − unconfidence
///
/// This means two rules each with weight 0.6 produce combined confidence
/// 1 − (0.4 × 0.4) = 0.84, reflecting how independent signals accumulate.
///
/// When `negate` is true the rule's raw match result is inverted before
/// contributing to confidence — the rule "matches" when the underlying
/// sensor condition is *absent*. This lets you express disqualifying
/// conditions such as "corporate VPN is NOT connected".
public struct Rule: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    /// The profile this rule contributes confidence to.
    public var profileID: UUID
    /// The sensor whose reading is tested, e.g. "com.controlplane.wifi".
    public var sensorID: String
    /// The reading key within that sensor's snapshot, e.g. "ssid".
    public var readingKey: String
    /// The operator to apply, e.g. "equals". Must be supported by `evaluatorID`.
    public var operatorID: String
    /// The value to compare the reading against.
    public var comparand: ObservationValue
    /// Which evaluator plugin performs the comparison. Defaults to the built-in basic evaluator.
    public var evaluatorID: String
    /// Confidence weight (0.0–1.0) contributed to the profile when this rule matches.
    /// A weight of 1.0 means a single matching rule brings the profile to full confidence.
    /// Lower values require additional matching rules to reach the profile's threshold.
    public var weight: Double
    /// When true, the rule's match result is inverted: it contributes confidence
    /// when the sensor condition is *not* met.
    public var negate: Bool
    public var enabled: Bool
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        profileID: UUID,
        sensorID: String,
        readingKey: String,
        operatorID: String,
        comparand: ObservationValue,
        evaluatorID: String = "com.controlplane.evaluator.basic",
        weight: Double = 1.0,
        negate: Bool = false,
        enabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.profileID = profileID
        self.sensorID = sensorID
        self.readingKey = readingKey
        self.operatorID = operatorID
        self.comparand = comparand
        self.evaluatorID = evaluatorID
        self.weight = weight
        self.negate = negate
        self.enabled = enabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Wire types

public struct RuleCreateRequest: Codable, Sendable {
    public var name: String
    public var profileID: UUID
    public var sensorID: String
    public var readingKey: String
    public var operatorID: String
    public var comparand: ObservationValue
    public var evaluatorID: String
    public var weight: Double
    public var negate: Bool

    public init(
        name: String,
        profileID: UUID,
        sensorID: String,
        readingKey: String,
        operatorID: String,
        comparand: ObservationValue,
        evaluatorID: String = "com.controlplane.evaluator.basic",
        weight: Double = 1.0,
        negate: Bool = false
    ) {
        self.name = name
        self.profileID = profileID
        self.sensorID = sensorID
        self.readingKey = readingKey
        self.operatorID = operatorID
        self.comparand = comparand
        self.evaluatorID = evaluatorID
        self.weight = weight
        self.negate = negate
    }
}

/// PUT semantics: all fields are replaced.
public struct RuleUpdateRequest: Codable, Sendable {
    public var name: String
    public var sensorID: String
    public var readingKey: String
    public var operatorID: String
    public var comparand: ObservationValue
    public var evaluatorID: String
    public var weight: Double
    public var negate: Bool
    public var enabled: Bool

    public init(
        name: String,
        sensorID: String,
        readingKey: String,
        operatorID: String,
        comparand: ObservationValue,
        evaluatorID: String = "com.controlplane.evaluator.basic",
        weight: Double = 1.0,
        negate: Bool = false,
        enabled: Bool = true
    ) {
        self.name = name
        self.sensorID = sensorID
        self.readingKey = readingKey
        self.operatorID = operatorID
        self.comparand = comparand
        self.evaluatorID = evaluatorID
        self.weight = weight
        self.negate = negate
        self.enabled = enabled
    }
}
