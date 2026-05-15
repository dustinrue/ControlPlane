import Foundation

/// A named state the system can be in. Multiple profiles can be active simultaneously
/// unless `exclusive` is set, in which case activating this profile deactivates siblings.
public struct Profile: Identifiable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var parentID: UUID?
    public var exclusive: Bool
    /// Minimum summed rule-weight needed to activate this profile.
    /// Default 1.0 means a single rule with weight 1.0 activates it.
    public var confidenceThreshold: Double
    public let createdAt: Date
    public var updatedAt: Date
    /// When this profile most recently became active. Nil until first activation.
    public var lastActivatedAt: Date?
    /// When this profile most recently became inactive. Nil until first deactivation.
    public var lastDeactivatedAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        parentID: UUID? = nil,
        exclusive: Bool = false,
        confidenceThreshold: Double = 1.0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastActivatedAt: Date? = nil,
        lastDeactivatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.parentID = parentID
        self.exclusive = exclusive
        self.confidenceThreshold = confidenceThreshold
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastActivatedAt = lastActivatedAt
        self.lastDeactivatedAt = lastDeactivatedAt
    }
}

// Custom Codable so confidenceThreshold defaults to 1.0 when absent (e.g. responses
// from an older backend that predates this field).
extension Profile: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, parentID, exclusive, confidenceThreshold
        case createdAt, updatedAt, lastActivatedAt, lastDeactivatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                  = try c.decode(UUID.self,   forKey: .id)
        name                = try c.decode(String.self, forKey: .name)
        parentID            = try c.decodeIfPresent(UUID.self,   forKey: .parentID)
        exclusive           = try c.decode(Bool.self,   forKey: .exclusive)
        confidenceThreshold = try c.decodeIfPresent(Double.self, forKey: .confidenceThreshold) ?? 1.0
        createdAt           = try c.decode(Date.self,   forKey: .createdAt)
        updatedAt           = try c.decode(Date.self,   forKey: .updatedAt)
        lastActivatedAt     = try c.decodeIfPresent(Date.self,   forKey: .lastActivatedAt)
        lastDeactivatedAt   = try c.decodeIfPresent(Date.self,   forKey: .lastDeactivatedAt)
    }
}

// MARK: - Wire types

/// Payload for creating a new profile.
public struct ProfileCreateRequest: Codable, Sendable {
    public var name: String
    public var parentID: UUID?
    public var exclusive: Bool
    public var confidenceThreshold: Double

    public init(
        name: String,
        parentID: UUID? = nil,
        exclusive: Bool = false,
        confidenceThreshold: Double = 1.0
    ) {
        self.name = name
        self.parentID = parentID
        self.exclusive = exclusive
        self.confidenceThreshold = confidenceThreshold
    }
}

/// Payload for updating an existing profile. All fields are replaced (PUT semantics).
/// The backend preserves `id` and `createdAt`; it sets a new `updatedAt`.
public struct ProfileUpdateRequest: Codable, Sendable {
    public var name: String
    public var parentID: UUID?
    public var exclusive: Bool
    public var confidenceThreshold: Double

    public init(
        name: String,
        parentID: UUID? = nil,
        exclusive: Bool = false,
        confidenceThreshold: Double = 1.0
    ) {
        self.name = name
        self.parentID = parentID
        self.exclusive = exclusive
        self.confidenceThreshold = confidenceThreshold
    }
}
