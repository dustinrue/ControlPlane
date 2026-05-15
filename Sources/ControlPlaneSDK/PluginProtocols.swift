import Foundation

// MARK: - Plugin base

/// Base protocol all plugins must conform to.
///
/// Conforming types must be NSObject subclasses — the bundle loader instantiates
/// plugins via `Bundle.principalClass` and dynamic `init()`, which requires ObjC
/// runtime support.
@objc public protocol ControlPlanePlugin: NSObjectProtocol {
    /// Reverse-DNS identifier, e.g. "com.controlplane.sensors.wifi"
    var pluginIdentifier: String { get }
    /// Human-readable name shown in the UI.
    var pluginDisplayName: String { get }
    /// Semantic version string, e.g. "1.0.0"
    var pluginVersion: String { get }
    /// Plugin category: "sensor", "action", or "intelligence"
    var pluginCategory: String { get }
}

// MARK: - Sensor plugins

/// Sensor plugins observe the environment and emit typed readings.
///
/// Conforming types must also satisfy ControlPlanePlugin (NSObject, @objc metadata).
/// The async methods allow sensors to use actors internally for thread safety while
/// remaining compatible with the NSObject-based plugin loading mechanism.
public protocol SensorPlugin: ControlPlanePlugin {
    /// Start observing. Idempotent — safe to call when already running.
    func start() async

    /// Stop observing and release any system resources. Idempotent.
    func stop() async

    /// Return the current snapshot of all readings. Must never throw or block
    /// indefinitely; return an inactive snapshot if the sensor is not running.
    func currentSnapshot() async -> SensorSnapshot

    /// Re-read hardware state and update the snapshot immediately.
    /// Called after external state changes (e.g. location authorization granted).
    /// Default implementation is a no-op.
    func refresh() async

    /// Returns true if this sensor can run on the current hardware/OS.
    /// The loader calls this before registering the sensor.
    static func isApplicable() -> Bool
}

public extension SensorPlugin {
    func refresh() async {}
}

// MARK: - Push sensor

/// A sensor that proactively notifies the coordinator whenever its snapshot
/// changes, rather than waiting for the coordinator to poll.
///
/// The coordinator sets `onSnapshotChanged` immediately after adding the sensor.
/// The sensor calls it at the end of every internal `refreshSnapshot()`.
/// This drives the rule engine in real time without polling.
public protocol PushSensor: SensorPlugin {
    var onSnapshotChanged: (@Sendable () -> Void)? { get set }
}

// MARK: - Dynamic-key sensor

/// A sensor whose observable keys are determined at runtime by the rules that
/// reference it, rather than by a fixed internal configuration.
///
/// Example: a file-presence sensor where each rule's `readingKey` is the path
/// to watch. The sensor emits one reading per path with a boolean value.
///
/// The backend calls `setMonitoredKeys(_:)` on startup and after any rule
/// change that affects this sensor's ID.
public protocol DynamicKeySensor: SensorPlugin {
    /// Replaces the current set of keys (e.g. file paths) the sensor should
    /// evaluate. Called by the backend; must not block.
    func setMonitoredKeys(_ keys: [String])
}

// MARK: - Action plugins

/// An action plugin defines a *type* of action (e.g. "send notification", "run script").
///
/// Users attach instances of an action type to specific profiles via the database.
/// Each instance carries its own key/value config (e.g. a custom message).
/// When a profile activates or deactivates the backend executes every attached,
/// enabled action whose trigger matches the event.
public protocol ActionPlugin: ControlPlanePlugin {
    /// Execute the action for the given profile transition.
    /// `config` is the per-instance key/value configuration stored with this action.
    func execute(trigger: ActionTrigger, profile: Profile, config: [String: String]) async throws

    /// Describes the config keys this action accepts, for UI / cpctl display.
    func configurationDescriptors() -> [ActionConfigDescriptor]
}
