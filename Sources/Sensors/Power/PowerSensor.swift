import Foundation
import IOKit
import IOKit.ps
import ControlPlaneSDK

// MARK: - C callback (must be a free function — no captures allowed)

private func powerSourceChanged(_ context: UnsafeMutableRawPointer?) {
    guard let ctx = context else { return }
    Unmanaged<PowerSensor>.fromOpaque(ctx).takeUnretainedValue().refreshSnapshot()
}

// MARK: - Sensor

/// Observes the current power source (AC adapter vs battery) and battery state
/// using IOPowerSources. Delivers push updates immediately when the power
/// source changes (adapter plugged/unplugged, charge level crosses thresholds).
public final class PowerSensor: NSObject, SensorPlugin, PushSensor {

    public var pluginIdentifier: String { "com.controlplane.sensors.power" }
    public var pluginDisplayName: String { "Power Source" }
    public var pluginVersion: String { "1.0.0" }
    public var pluginCategory: String { "sensor" }

    /// Injected by SensorCoordinator; called after every snapshot update.
    public var onSnapshotChanged: (@Sendable () -> Void)?

    private let lock = NSLock()
    private var _snapshot: SensorSnapshot

    /// Retained while running; released on stop() to balance passRetained in start().
    private var selfContext: UnsafeMutableRawPointer?
    private var runLoopSource: CFRunLoopSource?

    public override required init() {
        _snapshot = Self.inactive
        super.init()
    }

    // MARK: - SensorPlugin

    public static func isApplicable() -> Bool { true }

    public func start() async {
        refreshSnapshot()

        // Register an IOPowerSources run-loop source so we get a callback
        // immediately when the adapter is plugged/unplugged.
        let ctx = Unmanaged.passRetained(self).toOpaque()
        selfContext = ctx

        if let src = IOPSNotificationCreateRunLoopSource(powerSourceChanged, ctx)?.takeRetainedValue() {
            runLoopSource = src
            CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
        }
    }

    public func stop() async {
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .defaultMode)
            runLoopSource = nil
        }
        // Balance the passRetained from start().
        if let ctx = selfContext {
            Unmanaged<PowerSensor>.fromOpaque(ctx).release()
            selfContext = nil
        }
        lock.withLock { _snapshot = Self.inactive }
    }

    public func currentSnapshot() async -> SensorSnapshot {
        lock.withLock { _snapshot }
    }

    // MARK: - Internal

    /// Called from the IOPowerSources C callback and from start().
    func refreshSnapshot() {
        let blob   = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let list   = IOPSCopyPowerSourcesList(blob).takeRetainedValue() as [CFTypeRef]

        var onBattery  = true
        var percentage: Double? = nil
        var isCharging = false

        for ps in list {
            guard let raw = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue(),
                  let dict = raw as? [String: Any] else { continue }

            if (dict[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue {
                onBattery = false
            }
            if let current = dict[kIOPSCurrentCapacityKey] as? Int,
               let max     = dict[kIOPSMaxCapacityKey]     as? Int,
               max > 0 {
                percentage = Double(current) / Double(max) * 100.0
            }
            if let charging = dict[kIOPSIsChargingKey] as? Bool {
                isCharging = charging
            }
        }

        var readings: [SensorReading] = [
            SensorReading(key: "source",     label: "Power Source",      value: .string(onBattery ? "battery" : "ac")),
            SensorReading(key: "isCharging", label: "Charging",          value: .boolean(isCharging)),
            SensorReading(key: "isLowPower", label: "Low Power Mode",    value: .boolean(ProcessInfo.processInfo.isLowPowerModeEnabled)),
        ]
        if let pct = percentage {
            readings.append(SensorReading(key: "percentage", label: "Battery %", value: .number(pct.rounded())))
        }

        let snapshot = SensorSnapshot(
            sensorID:    pluginIdentifier,
            displayName: pluginDisplayName,
            readings:    readings,
            isActive:    true
        )
        lock.withLock { _snapshot = snapshot }
        onSnapshotChanged?()
    }

    // MARK: - Helpers

    private static var inactive: SensorSnapshot {
        SensorSnapshot(sensorID: "com.controlplane.sensors.power",
                       displayName: "Power Source", readings: [], isActive: false)
    }
}
