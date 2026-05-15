import Foundation

// MARK: - Backend status

/// Snapshot of backend health returned by `cpctl status`.
public struct BackendStatus: Sendable {
    public let pid: Int32
    public let version: String
    public let startedAt: Date
    public let profileCount: Int
    public let ruleCount: Int
    public let pluginCounts: PluginCounts

    public struct PluginCounts: Codable, Sendable {
        public let sensors: Int
        public let actions: Int
        public let intelligence: Int
        public let evaluators: Int

        public init(sensors: Int, actions: Int, intelligence: Int, evaluators: Int = 0) {
            self.sensors = sensors
            self.actions = actions
            self.intelligence = intelligence
            self.evaluators = evaluators
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            sensors     = try c.decode(Int.self, forKey: .sensors)
            actions     = try c.decode(Int.self, forKey: .actions)
            intelligence = try c.decode(Int.self, forKey: .intelligence)
            evaluators  = try c.decodeIfPresent(Int.self, forKey: .evaluators) ?? 0
        }
    }

    public init(
        pid: Int32,
        version: String,
        startedAt: Date,
        profileCount: Int,
        ruleCount: Int = 0,
        pluginCounts: PluginCounts
    ) {
        self.pid = pid
        self.version = version
        self.startedAt = startedAt
        self.profileCount = profileCount
        self.ruleCount = ruleCount
        self.pluginCounts = pluginCounts
    }
}

extension BackendStatus: Codable {
    enum CodingKeys: String, CodingKey {
        case pid, version, startedAt, profileCount, ruleCount, pluginCounts
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pid          = try c.decode(Int32.self,        forKey: .pid)
        version      = try c.decode(String.self,       forKey: .version)
        startedAt    = try c.decode(Date.self,         forKey: .startedAt)
        profileCount = try c.decode(Int.self,          forKey: .profileCount)
        ruleCount    = try c.decodeIfPresent(Int.self, forKey: .ruleCount) ?? 0
        pluginCounts = try c.decode(PluginCounts.self, forKey: .pluginCounts)
    }
}

// MARK: - Evaluator info

/// Metadata for a loaded evaluator plugin, returned by `cpctl evaluators list`.
public struct EvaluatorInfo: Codable, Sendable, Identifiable {
    public let id: String
    public let displayName: String
    public let version: String
    public let operators: [OperatorDescriptor]

    public init(id: String, displayName: String, version: String, operators: [OperatorDescriptor]) {
        self.id = id
        self.displayName = displayName
        self.version = version
        self.operators = operators
    }
}

// MARK: - Active profile

/// A profile that is currently active along with the confidence score that triggered it.
public struct ActiveProfile: Codable, Sendable {
    public let profile: Profile
    /// Sum of matched rule weights at the time of last evaluation.
    public let confidence: Double

    public init(profile: Profile, confidence: Double) {
        self.profile = profile
        self.confidence = confidence
    }
}

// MARK: - Plugin info

/// Metadata for a loaded plugin, returned by `cpctl plugins list`.
public struct PluginInfo: Codable, Sendable, Identifiable {
    public let id: String           // pluginIdentifier
    public let displayName: String
    public let version: String
    public let category: PluginCategory
    public let source: PluginSource

    public enum PluginCategory: String, Codable, Sendable {
        case sensor
        case action
        case intelligence
    }

    public enum PluginSource: String, Codable, Sendable {
        case bundled    // ships inside the app bundle
        case user       // installed by the user
    }

    public init(
        id: String,
        displayName: String,
        version: String,
        category: PluginCategory,
        source: PluginSource
    ) {
        self.id = id
        self.displayName = displayName
        self.version = version
        self.category = category
        self.source = source
    }
}
