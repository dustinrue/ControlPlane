import AppKit
import CoreGraphics
import ControlPlaneSDK

// MARK: - C callback (must be a free function — no captures allowed)

private func displayReconfigured(
    _ displayID: CGDirectDisplayID,
    _ flags: CGDisplayChangeSummaryFlags,
    _ context: UnsafeMutableRawPointer?
) {
    // kCGDisplayBeginConfigurationFlag fires before the change completes; skip it.
    guard !flags.contains(.beginConfigurationFlag) else { return }
    guard let ctx = context else { return }
    Unmanaged<MonitorSensor>.fromOpaque(ctx).takeUnretainedValue().refreshSnapshot()
}

// MARK: - Sensor

/// Observes connected displays using CoreGraphics + AppKit.
///
/// Emits one boolean reading per connected display (key = localized display name)
/// plus summary counts. Rules can therefore match on specific display names:
///
///   readingKey: "LG UltraFine 5K"   operator: equals   comparand: true
///   readingKey: "externalCount"      operator: >=       comparand: 1
public final class MonitorSensor: NSObject, SensorPlugin, PushSensor {

    public var pluginIdentifier: String { "com.controlplane.sensors.monitor" }
    public var pluginDisplayName: String { "Monitors" }
    public var pluginVersion: String { "1.0.0" }
    public var pluginCategory: String { "sensor" }

    /// Injected by SensorCoordinator; called after every snapshot update.
    public var onSnapshotChanged: (@Sendable () -> Void)?

    private let lock = NSLock()
    private var _snapshot: SensorSnapshot

    /// Retained while the callback is registered; released on stop().
    private var selfContext: UnsafeMutableRawPointer?

    public override required init() {
        _snapshot = Self.inactive
        super.init()
    }

    // MARK: - SensorPlugin

    public static func isApplicable() -> Bool { true }

    public func start() async {
        refreshSnapshot()

        let ctx = Unmanaged.passRetained(self).toOpaque()
        selfContext = ctx
        CGDisplayRegisterReconfigurationCallback(displayReconfigured, ctx)
    }

    public func stop() async {
        if let ctx = selfContext {
            CGDisplayRemoveReconfigurationCallback(displayReconfigured, ctx)
            Unmanaged<MonitorSensor>.fromOpaque(ctx).release()
            selfContext = nil
        }
        lock.withLock { _snapshot = Self.inactive }
    }

    public func currentSnapshot() async -> SensorSnapshot {
        lock.withLock { _snapshot }
    }

    // MARK: - Internal

    /// Enumerates all online displays and rebuilds the snapshot.
    /// Safe to call from any thread; dispatches to main for NSScreen access.
    func refreshSnapshot() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // NSScreen.screens is the authoritative list on the main thread.
            let screens = NSScreen.screens

            var readings: [SensorReading] = []
            var externalCount = 0

            for screen in screens {
                guard let displayID = screen.deviceDescription[
                    NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
                else { continue }

                let name = screen.localizedName
                let isBuiltIn = CGDisplayIsBuiltin(displayID) != 0

                if !isBuiltIn { externalCount += 1 }

                // One boolean reading per display — key is the human name.
                readings.append(SensorReading(
                    key:   name,
                    label: name,
                    value: .boolean(true)
                ))
            }

            // Summary counts as separate numeric readings.
            readings.append(SensorReading(key: "count",         label: "Total Displays",    value: .number(Double(screens.count))))
            readings.append(SensorReading(key: "externalCount", label: "External Displays",  value: .number(Double(externalCount))))

            let snapshot = SensorSnapshot(
                sensorID:    self.pluginIdentifier,
                displayName: self.pluginDisplayName,
                readings:    readings,
                isActive:    true
            )
            self.lock.withLock { self._snapshot = snapshot }
            self.onSnapshotChanged?()
        }
    }

    // MARK: - Helpers

    private static var inactive: SensorSnapshot {
        SensorSnapshot(sensorID: "com.controlplane.sensors.monitor",
                       displayName: "Monitors", readings: [], isActive: false)
    }
}
