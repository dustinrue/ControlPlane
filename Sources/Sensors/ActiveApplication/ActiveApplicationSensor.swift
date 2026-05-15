import Foundation
import AppKit
import ControlPlaneSDK

public final class ActiveApplicationSensor: BaseSensor {

    public override var pluginIdentifier: String  { "com.controlplane.sensors.activeapplication" }
    public override var pluginDisplayName: String { "Active Application" }

    private var observer: NSObjectProtocol?

    public override required init() {
        super.init()
    }

    public override func start() async {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshSnapshot() }
        }
        DispatchQueue.main.sync { refreshSnapshot() }
    }

    public override func stop() async {
        if let obs = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            observer = nil
        }
        publishInactive()
    }

    private func refreshSnapshot() {
        let app = NSWorkspace.shared.frontmostApplication
        let bundleID = app?.bundleIdentifier ?? ""
        let name = app?.localizedName ?? ""
        publishSnapshot(readings: [
            SensorReading(key: "bundleID", label: "Bundle ID",  value: .string(bundleID)),
            SensorReading(key: "name",     label: "App Name",   value: .string(name)),
        ])
    }
}
