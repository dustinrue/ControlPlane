import Foundation
import IOBluetooth
import ControlPlaneSDK

public final class BluetoothSensor: BaseSensor {

    public override var pluginIdentifier: String  { "com.controlplane.sensors.bluetooth" }
    public override var pluginDisplayName: String { "Bluetooth" }

    private var connectNotification: IOBluetoothUserNotification?
    private var deviceDisconnectNotifications: [IOBluetoothUserNotification] = []
    private var pollTask: Task<Void, Never>?

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
        // Subsequent updates happen on the 30-second poll cycle.
        pollTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled, let self else { return }
            await MainActor.run {
                self.connectNotification = IOBluetoothDevice.register(
                    forConnectNotifications: self,
                    selector: #selector(self.deviceConnected(_:device:))
                )
            }
            self.refreshSnapshot()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { return }
                self.refreshSnapshot()
            }
        }
    }

    public override func stop() async {
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
