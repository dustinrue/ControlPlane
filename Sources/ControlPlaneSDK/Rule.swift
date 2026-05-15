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
/// A profile can have many rules; each matching rule adds its `weight` to the
/// profile's confidence score. When the score reaches the profile's
/// `confidenceThreshold`, the profile becomes active.
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
    /// Confidence points added to the profile when this rule matches.
    public var weight: Double
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

    public init(
        name: String,
        profileID: UUID,
        sensorID: String,
        readingKey: String,
        operatorID: String,
        comparand: ObservationValue,
        evaluatorID: String = "com.controlplane.evaluator.basic",
        weight: Double = 1.0
    ) {
        self.name = name
        self.profileID = profileID
        self.sensorID = sensorID
        self.readingKey = readingKey
        self.operatorID = operatorID
        self.comparand = comparand
        self.evaluatorID = evaluatorID
        self.weight = weight
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
    public var enabled: Bool

    public init(
        name: String,
        sensorID: String,
        readingKey: String,
        operatorID: String,
        comparand: ObservationValue,
        evaluatorID: String = "com.controlplane.evaluator.basic",
        weight: Double = 1.0,
        enabled: Bool = true
    ) {
        self.name = name
        self.sensorID = sensorID
        self.readingKey = readingKey
        self.operatorID = operatorID
        self.comparand = comparand
        self.evaluatorID = evaluatorID
        self.weight = weight
        self.enabled = enabled
    }
}
