import os

// MARK: - Log Level

enum CPLogLevel: Int, Comparable, CaseIterable {
    case off   = 0
    case info  = 1
    case debug = 2

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .off:   return "Off"
        case .info:  return "Info"
        case .debug: return "Debug"
        }
    }
}

// MARK: - Logger namespace

enum CPLogger {
    static let subsystem = "com.controlplane.app"

    /// General / uncategorised app events
    static let general  = Logger(subsystem: subsystem, category: "General")
    /// Sensor lifecycle and snapshot callbacks
    static let sensors  = Logger(subsystem: subsystem, category: "Sensors")
    /// Rule evaluation detail
    static let rules    = Logger(subsystem: subsystem, category: "RuleEngine")
    /// Profile activation and profile-store CRUD
    static let profiles = Logger(subsystem: subsystem, category: "Profiles")
    /// Action execution and action-store CRUD
    static let actions  = Logger(subsystem: subsystem, category: "Actions")
    /// Plugin / bundle loading
    static let plugins  = Logger(subsystem: subsystem, category: "Plugins")
    /// Unix-socket server
    static let socket   = Logger(subsystem: subsystem, category: "Socket")
    /// App setup: location auth, cpctl installer, database
    static let setup    = Logger(subsystem: subsystem, category: "Setup")

    /// UserDefaults key for the persisted log level (stored as Int rawValue).
    static let levelKey = "com.controlplane.logLevel"

    /// The currently active log level, read from UserDefaults on every access so
    /// changes in the Preferences UI take effect immediately without a restart.
    static var activeLevel: CPLogLevel {
        CPLogLevel(rawValue: UserDefaults.standard.integer(forKey: levelKey)) ?? .off
    }
}

// MARK: - Global helpers

/// Log an informational message. Gated by CPLogLevel.info (or higher).
/// Drop-in replacement for the old print()-based log() function — existing call sites
/// that omit the logger argument continue to work unchanged.
func log(_ message: String, _ logger: Logger = CPLogger.general) {
    guard CPLogger.activeLevel >= .info else { return }
    logger.info("\(message, privacy: .public)")
}

/// Log a verbose / debug message. Only emitted at CPLogLevel.debug.
func logDebug(_ message: String, _ logger: Logger = CPLogger.general) {
    guard CPLogger.activeLevel >= .debug else { return }
    logger.debug("\(message, privacy: .public)")
}

/// Log an error. Always emitted regardless of the active log level.
func logError(_ message: String, _ logger: Logger = CPLogger.general) {
    logger.error("\(message, privacy: .public)")
}
