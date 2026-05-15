import Foundation
import ControlPlaneSDK

public final class ScreenLockSensor: BaseSensor {

    public override var pluginIdentifier: String  { "com.controlplane.sensors.screenlock" }
    public override var pluginDisplayName: String { "Screen Lock" }

    private var lockedObserver: NSObjectProtocol?
    private var unlockedObserver: NSObjectProtocol?
    private var locked = false

    public override required init() {
        super.init()
    }

    public override func start() async {
        let center = DistributedNotificationCenter.default()
        lockedObserver = center.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.locked = true
            self?.publishCurrentState()
        }
        unlockedObserver = center.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.locked = false
            self?.publishCurrentState()
        }
        locked = false
        publishCurrentState()
    }

    public override func stop() async {
        let center = DistributedNotificationCenter.default()
        if let obs = lockedObserver {
            center.removeObserver(obs)
            lockedObserver = nil
        }
        if let obs = unlockedObserver {
            center.removeObserver(obs)
            unlockedObserver = nil
        }
        publishInactive()
    }

    private func publishCurrentState() {
        publishSnapshot(readings: [
            SensorReading(key: "locked", label: "Screen Locked", value: .boolean(locked))
        ])
    }
}
