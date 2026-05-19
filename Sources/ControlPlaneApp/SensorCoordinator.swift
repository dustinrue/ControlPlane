import Foundation
import ControlPlaneSDK

/// Manages the lifecycle of all loaded SensorPlugin instances and vends snapshots on demand.
///
/// ## Run policy
///
/// All registered sensors are always *known* to the coordinator, but only a
/// subset may be *running* at any given time.  The policy is:
///
/// - **Settings window open**: all sensors run (so the Sensors tab shows live
///   readings and the user can create rules for any sensor).
/// - **Settings window closed**: only sensors referenced by at least one enabled
///   rule run.  Sensors with no rules are stopped to keep CPU usage near zero.
///
/// `Backend` calls `applyRunPolicy(neededIDs:)` after rules change and after the
/// settings window closes.  `PreferencesWindowController` calls `startAll()` when
/// the window opens and `applyRunPolicy(neededIDs:)` when it closes.
actor SensorCoordinator {
    /// All registered sensor instances, whether running or not.
    private var sensors: [String: any SensorPlugin] = [:]
    /// IDs of sensors that are currently started.
    private var runningSensors: Set<String> = []

    private let configStore: SensorConfigStore

    private var onSnapshotsUpdated: (@Sendable ([SensorSnapshot]) async -> Void)?

    func setSnapshotCallback(_ callback: @escaping @Sendable ([SensorSnapshot]) async -> Void) {
        onSnapshotsUpdated = callback
    }

    init(configStore: SensorConfigStore) {
        self.configStore = configStore
    }

    // MARK: - Registration

    /// Register a sensor and wire its push callback, but do NOT start it yet.
    /// Call `applyRunPolicy(neededIDs:)` or `startAll()` afterwards.
    func register(_ sensor: any SensorPlugin) async {
        let id = sensor.pluginIdentifier

        if let configurable = sensor as? any ConfigurableSensor {
            let saved = await configStore.options(for: id)
            for (key, value) in saved {
                try? configurable.setOption(key: key, value: value)
            }
        }

        if let push = sensor as? any PushSensor {
            push.onSnapshotChanged = { [weak self] in
                Task { await self?.triggerSnapshotCallback() }
            }
        }

        sensors[id] = sensor
        logDebug("Registered sensor: \(id)", CPLogger.sensors)
    }

    // MARK: - Run policy

    /// Start all registered sensors. Used when the settings window opens so
    /// the user sees live readings for every sensor.
    func startAll() async {
        for (id, sensor) in sensors where !runningSensors.contains(id) {
            await sensor.start()
            runningSensors.insert(id)
            log("Started sensor (settings open): \(id)", CPLogger.sensors)
        }
    }

    /// Start sensors in `neededIDs`, stop all others.
    /// Called after rules change or after the settings window closes.
    func applyRunPolicy(neededIDs: Set<String>) async {
        // Stop sensors that are running but no longer needed.
        for id in runningSensors where !neededIDs.contains(id) {
            if let sensor = sensors[id] {
                await sensor.stop()
                log("Stopped idle sensor (no rules): \(id)", CPLogger.sensors)
            }
            runningSensors.remove(id)
        }
        // Start sensors that are needed but not yet running.
        for id in neededIDs {
            guard !runningSensors.contains(id), let sensor = sensors[id] else { continue }
            await sensor.start()
            runningSensors.insert(id)
            log("Started sensor (has rules): \(id)", CPLogger.sensors)
        }
    }

    /// Legacy entry point kept for compatibility — registers and immediately starts.
    func add(_ sensor: any SensorPlugin) async {
        await register(sensor)
        let id = sensor.pluginIdentifier
        await sensor.start()
        runningSensors.insert(id)
        log("Started sensor: \(id)", CPLogger.sensors)
    }

    /// Returns the IDs of all registered sensors (running or not).
    func allRegisteredIDs() -> Set<String> {
        Set(sensors.keys)
    }

    /// Returns the IDs of currently running sensors.
    func runningIDs() -> Set<String> {
        runningSensors
    }

    /// Current snapshots from every *registered* sensor, sorted by sensor ID.
    /// Stopped sensors are included with isActive = false so the Sensors tab
    /// can still list them (they just show as inactive).
    func allSnapshots() async -> [SensorSnapshot] {
        var result: [SensorSnapshot] = []
        for sensor in sensors.values {
            result.append(await sensor.currentSnapshot())
        }
        return result.sorted { $0.sensorID < $1.sensorID }
    }

    /// Snapshot for a single sensor, or nil if that ID is not registered.
    func snapshot(for id: String) async -> SensorSnapshot? {
        guard let sensor = sensors[id] else { return nil }
        return await sensor.currentSnapshot()
    }

    /// Fire the snapshot callback with the current snapshots from all sensors.
    /// Called by PushSensor callbacks and by refreshAllSensors.
    ///
    /// The callback is awaited directly (not wrapped in a new Task) so that
    /// successive calls from rapid sensor events — e.g. unmount immediately
    /// followed by remount — are serialised through the actor and evaluated in
    /// the order they arrived.  Spawning an unstructured Task here caused the
    /// unmount evaluation to sometimes win a race against the remount evaluation
    /// at the RuleEngine actor, leaving the profile incorrectly deactivated.
    func triggerSnapshotCallback() async {
        guard let onChange = onSnapshotsUpdated else {
            logDebug("[SensorCoordinator] triggerSnapshotCallback — onSnapshotsUpdated is nil, skipping", CPLogger.sensors)
            return
        }
        let snapshots = await allSnapshots()
        logDebug("[SensorCoordinator] triggerSnapshotCallback — evaluating with \(snapshots.count) snapshots", CPLogger.sensors)
        await onChange(snapshots)
    }

    /// Ask every sensor to re-read hardware state — called after location authorization changes.
    func refreshAllSensors() async {
        for sensor in sensors.values {
            await sensor.refresh()
        }
        log("Sensor snapshots refreshed", CPLogger.sensors)
        await triggerSnapshotCallback()
    }

    // MARK: - Configuration

    func getOptions(for id: String) throws -> [SensorOptionDescriptor] {
        guard let sensor = sensors[id] else {
            throw CPError.invalidData("No sensor loaded with identifier '\(id)'")
        }
        guard let configurable = sensor as? any ConfigurableSensor else {
            throw CPError.invalidData("Sensor '\(id)' does not support configuration")
        }
        return configurable.options()
    }

    func setOption(for id: String, key: String, value: SensorOptionValue) async throws {
        guard let sensor = sensors[id] else {
            throw CPError.invalidData("No sensor loaded with identifier '\(id)'")
        }
        guard let configurable = sensor as? any ConfigurableSensor else {
            throw CPError.invalidData("Sensor '\(id)' does not support configuration")
        }
        try configurable.setOption(key: key, value: value)
        await configStore.set(key: key, value: value, for: id)
        log("Set option \(key)=\(value) on sensor \(id)", CPLogger.sensors)
    }

    /// Returns the IDs of all loaded sensors that conform to DynamicKeySensor.
    func dynamicSensorIDs() -> [String] {
        sensors.compactMap { id, sensor in
            (sensor as? any DynamicKeySensor) != nil ? id : nil
        }
    }

    /// Push a new key set to any DynamicKeySensor with the given ID.
    func setMonitoredKeys(_ keys: [String], forSensor id: String) {
        guard let sensor = sensors[id], let dynamic = sensor as? any DynamicKeySensor else { return }
        dynamic.setMonitoredKeys(keys)
    }

    /// Stop all sensors — called on backend shutdown.
    func stopAll() async {
        for sensor in sensors.values {
            await sensor.stop()
        }
        sensors.removeAll()
        log("All sensors stopped", CPLogger.sensors)
    }
}
