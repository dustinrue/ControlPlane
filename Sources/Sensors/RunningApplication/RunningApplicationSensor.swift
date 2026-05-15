import Foundation
import AppKit
import ControlPlaneSDK

public final class RunningApplicationSensor: BaseSensor, DynamicKeySensor {

    public override var pluginIdentifier: String  { "com.controlplane.sensors.runningapplication" }
    public override var pluginDisplayName: String { "Running Application" }

    private var watchedIDs: [String] = []
    private var launchObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?

    public override required init() {
        super.init()
    }

    public override func start() async {
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshSnapshot() }
        }
        terminateObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshSnapshot() }
        }
        DispatchQueue.main.sync { refreshSnapshot() }
    }

    public override func stop() async {
        if let obs = launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            launchObserver = nil
        }
        if let obs = terminateObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            terminateObserver = nil
        }
        publishInactive()
    }

    public func setMonitoredKeys(_ keys: [String]) {
        watchedIDs = keys
        DispatchQueue.main.async { [weak self] in self?.refreshSnapshot() }
    }

    private func refreshSnapshot() {
        let readings = watchedIDs.map { bundleID -> SensorReading in
            let running = !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
            return SensorReading(key: bundleID, label: bundleID, value: .boolean(running))
        }
        publishSnapshot(readings: readings)
    }
}
