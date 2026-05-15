import Foundation

/// Convenience base class for sensor plugins.
///
/// Subclasses must override:
///   - `pluginIdentifier`
///   - `pluginDisplayName`
///   - `start() async`
///   - `stop() async`
///
/// After updating readings, call `publishSnapshot(readings:isActive:)` which
/// handles locking and fires `onSnapshotChanged` automatically.
///
/// `pluginCategory` is fixed to `"sensor"` and must not be overridden.
open class BaseSensor: NSObject, SensorPlugin, PushSensor {

    // MARK: - PushSensor
    public var onSnapshotChanged: (@Sendable () -> Void)?

    // MARK: - Internal state
    private let lock = NSLock()
    private var _snapshot: SensorSnapshot

    // MARK: - ControlPlanePlugin (subclasses override)
    open var pluginIdentifier: String  { "" }
    open var pluginDisplayName: String { "" }
    open var pluginVersion: String     { "1.0.0" }
    /// Fixed to "sensor" — do not override.
    public final var pluginCategory: String { "sensor" }

    // MARK: - Init
    public override required init() {
        _snapshot = SensorSnapshot(sensorID: "", displayName: "", readings: [], isActive: false)
        super.init()
        // Re-init now that dynamic dispatch resolves to subclass overrides.
        _snapshot = SensorSnapshot(
            sensorID:    pluginIdentifier,
            displayName: pluginDisplayName,
            readings:    [],
            isActive:    false
        )
    }

    // MARK: - SensorPlugin
    open func start()   async {}
    open func stop()    async {}
    open func refresh() async {}
    open class func isApplicable() -> Bool { true }

    public func currentSnapshot() async -> SensorSnapshot {
        lock.withLock { _snapshot }
    }

    // MARK: - Helpers for subclasses

    /// Build a new snapshot from the given readings and notify the coordinator.
    /// Call this whenever sensor state changes.
    public func publishSnapshot(readings: [SensorReading], isActive: Bool = true) {
        let snap = SensorSnapshot(
            sensorID:    pluginIdentifier,
            displayName: pluginDisplayName,
            readings:    readings,
            isActive:    isActive
        )
        lock.withLock { _snapshot = snap }
        onSnapshotChanged?()
    }

    /// Publish an empty inactive snapshot (e.g. after stop()).
    public func publishInactive() {
        publishSnapshot(readings: [], isActive: false)
    }
}
