import Foundation
import ControlPlaneSDK

/// Manages the lifecycle of all loaded SensorPlugin instances and vends snapshots on demand.
actor SensorCoordinator {
    private var sensors: [String: any SensorPlugin] = [:]
    private let configStore: SensorConfigStore

    private var onSnapshotsUpdated: (@Sendable ([SensorSnapshot]) async -> Void)?

    func setSnapshotCallback(_ callback: @escaping @Sendable ([SensorSnapshot]) async -> Void) {
        onSnapshotsUpdated = callback
    }

    init(configStore: SensorConfigStore) {
        self.configStore = configStore
    }

    /// Register a sensor, apply any persisted options, then start it.
    func add(_ sensor: any SensorPlugin) async {
        let id = sensor.pluginIdentifier

        if let configurable = sensor as? any ConfigurableSensor {
            let saved = await configStore.options(for: id)
            for (key, value) in saved {
                try? configurable.setOption(key: key, value: value)
            }
        }

        // If the sensor supports push notifications, inject a callback so
        // changes it detects internally (kqueue events, CoreWLAN notifications, …)
        // drive the rule engine in real time without polling.
        if let push = sensor as? any PushSensor {
            push.onSnapshotChanged = { [weak self] in
                Task { await self?.triggerSnapshotCallback() }
            }
        }

        sensors[id] = sensor
        await sensor.start()
        log("Started sensor: \(id)", CPLogger.sensors)
    }

    /// Current snapshots from every sensor, sorted by sensor ID.
    func allSnapshots() async -> [SensorSnapshot] {
        var result: [SensorSnapshot] = []
        for sensor in sensors.values {
            result.append(await sensor.currentSnapshot())
        }
        return result.sorted { $0.sensorID < $1.sensorID }
    }

    /// Snapshot for a single sensor, or nil if that ID is not loaded.
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
