import Foundation
import IOBluetooth
import ControlPlaneSDK

/// Sensor that observes Bluetooth hardware state using IOBluetooth.
///
/// Always emits: powered, devices, per-device MAC readings.
/// Connect/disconnect notifications handle real-time updates for devices
/// and device-presence keys. The 30-second poll loop (needed to catch
/// power-state changes that notifications miss) only runs when at least
/// one rule references a Bluetooth key. When no rules use this sensor
/// the poll loop is stopped, eliminating unnecessary background wakeups.
public final class BluetoothSensor: BaseSensor, DynamicKeySensor {

    public override var pluginIdentifier: String  { "com.controlplane.sensors.bluetooth" }
    public override var pluginDisplayName: String { "Bluetooth" }

    private var connectNotification: IOBluetoothUserNotification?
    private var deviceDisconnectNotifications: [IOBluetoothUserNotification] = []
    private var initTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var monitoredKeys: Set<String> = []

    public override required init() {
        super.init()
    }

    /// Bluetooth hardware is present on all supported Mac models.
    /// Never call IOBluetooth here — it triggers the TCC Bluetooth permission
    /// check before the app has fully launched and can present the dialog.
    public override class func isApplicable() -> Bool { true }

    public override func start() async {
        // Defer the first IOBluetooth access by 2 seconds so the app is fully
        // running and the TCC permission dialog can be presented to the user.
        // The poll loop is NOT started here — setMonitoredKeys drives that.
        initTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled, let self else { return }
            await MainActor.run {
                self.connectNotification = IOBluetoothDevice.register(
                    forConnectNotifications: self,
                    selector: #selector(self.deviceConnected(_:device:))
                )
            }
            self.refreshSnapshot()
        }
    }

    public override func stop() async {
        initTask?.cancel()
        initTask = nil
        pollTask?.cancel()
        pollTask = nil
        await MainActor.run {
            connectNotification?.unregister()
            connectNotification = nil
            for note in deviceDisconnectNotifications { note.unregister() }
            deviceDisconnectNotifications.removeAll()
        }
        publishInactive()
    }

    // MARK: - DynamicKeySensor

    /// Called by the backend after every rule change.
    /// Starts the poll loop when any rule references a Bluetooth key;
    /// stops it when no rules do.
    public func setMonitoredKeys(_ keys: [String]) {
        let wasMonitoring = !monitoredKeys.isEmpty
        let nowMonitoring = !keys.isEmpty
        monitoredKeys = Set(keys)

        guard wasMonitoring != nowMonitoring else { return }

        if nowMonitoring {
            print("[BluetoothSensor] rules reference Bluetooth keys — starting poll loop")
            pollTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                    guard !Task.isCancelled else { return }
                    self?.refreshSnapshot()
                }
            }
        } else {
            print("[BluetoothSensor] no rules reference Bluetooth keys — stopping poll loop")
            pollTask?.cancel()
            pollTask = nil
        }
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let note = device.register(forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:)))
        if let n = note {
            deviceDisconnectNotifications.append(n)
        }
        refreshSnapshot()
    }

    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        deviceDisconnectNotifications.removeAll { $0 === notification }
        refreshSnapshot()
    }

    private func refreshSnapshot() {
        let paired    = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        let connected = paired.filter { $0.isConnected() }
        let names     = connected.compactMap { $0.name }
        let powered   = IOBluetoothHostController.default()?.powerState == kBluetoothHCIPowerStateON

        var readings: [SensorReading] = [
            SensorReading(key: "devices", label: "Connected Devices", value: .strings(names)),
            SensorReading(key: "powered", label: "Bluetooth Powered",  value: .boolean(powered)),
        ]
        for device in connected {
            if let addr = device.addressString {
                readings.append(SensorReading(key: addr, label: device.name ?? addr, value: .boolean(true)))
            }
        }
        publishSnapshot(readings: readings)
    }
}
