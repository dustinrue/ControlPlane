import Foundation

// MARK: - Trigger

/// When a profile action fires.
public enum ActionTrigger: String, Codable, Sendable, CaseIterable {
    /// Fires when the profile's confidence reaches its threshold and it becomes active.
    case onActivate
    /// Fires when the profile's confidence drops below its threshold and it becomes inactive.
    case onDeactivate
}

// MARK: - Config descriptor

/// Describes one configuration key an action plugin accepts.
/// Used by the UI and cpctl to show what can be configured.
public struct ActionConfigDescriptor: Codable, Sendable {
    public let key: String
    public let label: String
    public let description: String
    public let required: Bool
    public let defaultValue: String?

    public init(
        key: String,
        label: String,
        description: String,
        required: Bool = false,
        defaultValue: String? = nil
    ) {
        self.key = key
        self.label = label
        self.description = description
        self.required = required
        self.defaultValue = defaultValue
    }
}

// MARK: - Action type info

/// Metadata for a loaded action plugin, returned by `cpctl action-types list`.
public struct ActionTypeInfo: Codable, Sendable, Identifiable {
    public let id: String            // pluginIdentifier
    public let displayName: String
    public let version: String
    public let configDescriptors: [ActionConfigDescriptor]

    public init(id: String, displayName: String, version: String, configDescriptors: [ActionConfigDescriptor]) {
        self.id = id
        self.displayName = displayName
        self.version = version
        self.configDescriptors = configDescriptors
    }
}

// MARK: - Action (global reusable definition)

/// A named, reusable action definition stored in the global library.
/// Not tied to any profile — profiles reference actions via `ProfileActionLink`.
public struct Action: Identifiable, Sendable, Equatable {
    public let id: UUID
    /// Human-readable name chosen by the user (e.g. "Connect VPN").
    public var name: String
    /// Which action plugin executes this (e.g. "com.controlplane.action.shellscript").
    public var actionPluginID: String
    /// Plugin-specific key/value configuration.
    public var config: [String: String]
    public var enabled: Bool
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        actionPluginID: String,
        config: [String: String] = [:],
        enabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.actionPluginID = actionPluginID
        self.config = config
        self.enabled = enabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - ProfileActionLink (profile ↔ action assignment)

/// Links a global `Action` to a `Profile` with a trigger and enabled flag.
/// Replaces the old `ProfileAction` which embedded the action definition inline.
public struct ProfileActionLink: Identifiable, Sendable, Equatable {
    public let id: UUID
    public var profileID: UUID
    public var actionID: UUID
    /// When this action fires relative to the profile.
    public var trigger: ActionTrigger
    public var enabled: Bool
    public let createdAt: Date
    /// When this link was most recently executed. Nil until first execution.
    public var lastTriggeredAt: Date?

    public init(
        id: UUID = UUID(),
        profileID: UUID,
        actionID: UUID,
        trigger: ActionTrigger,
        enabled: Bool = true,
        createdAt: Date = Date(),
        lastTriggeredAt: Date? = nil
    ) {
        self.id = id
        self.profileID = profileID
        self.actionID = actionID
        self.trigger = trigger
        self.enabled = enabled
        self.createdAt = createdAt
        self.lastTriggeredAt = lastTriggeredAt
    }
}

// MARK: - ProfileAction (legacy alias — kept for backward compat during transition)

/// A specific action attached to a profile, stored in the database.
/// When the profile transitions, the backend executes this action via the plugin
/// identified by `actionPluginID`, passing `config` as runtime parameters.
public struct ProfileAction: Identifiable, Sendable, Equatable {
    public let id: UUID
    /// The profile this action belongs to.
    public var profileID: UUID
    /// Which action plugin handles this (e.g. "com.controlplane.action.notification").
    public var actionPluginID: String
    /// When this action fires.
    public var trigger: ActionTrigger
    /// Plugin-specific key/value configuration (e.g. ["title": "Away mode on"]).
    public var config: [String: String]
    public var enabled: Bool
    public let createdAt: Date
    public var updatedAt: Date
    /// When this action was most recently executed. Nil until first execution.
    public var lastTriggeredAt: Date?

    public init(
        id: UUID = UUID(),
        profileID: UUID,
        actionPluginID: String,
        trigger: ActionTrigger,
        config: [String: String] = [:],
        enabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastTriggeredAt: Date? = nil
    ) {
        self.id = id
        self.profileID = profileID
        self.actionPluginID = actionPluginID
        self.trigger = trigger
        self.config = config
        self.enabled = enabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastTriggeredAt = lastTriggeredAt
    }
}

extension ProfileAction: Codable {
    enum CodingKeys: String, CodingKey {
        case id, profileID, actionPluginID, trigger, config, enabled
        case createdAt, updatedAt, lastTriggeredAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(UUID.self,            forKey: .id)
        profileID       = try c.decode(UUID.self,            forKey: .profileID)
        actionPluginID  = try c.decode(String.self,          forKey: .actionPluginID)
        trigger         = try c.decode(ActionTrigger.self,   forKey: .trigger)
        config          = try c.decode([String:String].self, forKey: .config)
        enabled         = try c.decode(Bool.self,            forKey: .enabled)
        createdAt       = try c.decode(Date.self,            forKey: .createdAt)
        updatedAt       = try c.decode(Date.self,            forKey: .updatedAt)
        lastTriggeredAt = try c.decodeIfPresent(Date.self,   forKey: .lastTriggeredAt)
    }
}

// MARK: - Wire types

public struct ProfileActionCreateRequest: Codable, Sendable {
    public var profileID: UUID
    public var actionPluginID: String
    public var trigger: ActionTrigger
    public var config: [String: String]

    public init(
        profileID: UUID,
        actionPluginID: String,
        trigger: ActionTrigger,
        config: [String: String] = [:]
    ) {
        self.profileID = profileID
        self.actionPluginID = actionPluginID
        self.trigger = trigger
        self.config = config
    }
}

public struct ProfileActionUpdateRequest: Codable, Sendable {
    public var actionPluginID: String
    public var trigger: ActionTrigger
    public var config: [String: String]
    public var enabled: Bool

    public init(
        actionPluginID: String,
        trigger: ActionTrigger,
        config: [String: String] = [:],
        enabled: Bool = true
    ) {
        self.actionPluginID = actionPluginID
        self.trigger = trigger
        self.config = config
        self.enabled = enabled
    }
}
