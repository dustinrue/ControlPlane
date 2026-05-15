import Foundation
import IOKit
import ControlPlaneSDK

// MARK: - C-level callbacks (no captures allowed)

private func usbDeviceAdded(_ refCon: UnsafeMutableRawPointer?, _ iterator: io_iterator_t) {
    guard let ptr = refCon else { return }
    Unmanaged<USBSensor>.fromOpaque(ptr).takeUnretainedValue().devAdded(iterator)
}

private func usbDeviceRemoved(_ refCon: UnsafeMutableRawPointer?, _ iterator: io_iterator_t) {
    guard let ptr = refCon else { return }
    Unmanaged<USBSensor>.fromOpaque(ptr).takeUnretainedValue().devRemoved(iterator)
}

// MARK: - Sensor

public final class USBSensor: BaseSensor, DynamicKeySensor {

    public override var pluginIdentifier: String  { "com.controlplane.sensors.usb" }
    public override var pluginDisplayName: String { "USB Device" }

    private struct USBDevice {
        let vendorID: Int
        let productID: Int
        let name: String
    }

    private let devLock = NSLock()
    private var connectedDevices: [USBDevice] = []
    private var watchedKeys: [String] = []

    private var notifyPort: IONotificationPortRef?
    private var addedIterators:   [io_iterator_t] = []
    private var removedIterators: [io_iterator_t] = []

    public override required init() {
        super.init()
    }

    public override func start() async {
        notifyPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let port = notifyPort else { return }
        let rl = IONotificationPortGetRunLoopSource(port)!.takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), rl, .defaultMode)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        for matchName in ["IOUSBDevice", "IOUSBHostDevice"] {
            // Added notifications
            if let matching = IOServiceMatching(matchName) {
                var addedIter: io_iterator_t = 0
                let kr = IOServiceAddMatchingNotification(
                    port,
                    kIOFirstMatchNotification,
                    matching,
                    usbDeviceAdded,
                    selfPtr,
                    &addedIter
                )
                if kr == KERN_SUCCESS {
                    addedIterators.append(addedIter)
                    devAdded(addedIter)
                }
            }
            // Removed notifications
            if let matching2 = IOServiceMatching(matchName) {
                var removedIter: io_iterator_t = 0
                let kr = IOServiceAddMatchingNotification(
                    port,
                    kIOTerminatedNotification,
                    matching2,
                    usbDeviceRemoved,
                    selfPtr,
                    &removedIter
                )
                if kr == KERN_SUCCESS {
                    removedIterators.append(removedIter)
                    devRemoved(removedIter)
                }
            }
        }
    }

    public override func stop() async {
        for iter in addedIterators   { IOObjectRelease(iter) }
        for iter in removedIterators { IOObjectRelease(iter) }
        addedIterators.removeAll()
        removedIterators.removeAll()
        if let port = notifyPort {
            if let rl = IONotificationPortGetRunLoopSource(port) {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), rl.takeUnretainedValue(), .defaultMode)
            }
            IONotificationPortDestroy(port)
            notifyPort = nil
        }
        devLock.withLock { connectedDevices.removeAll() }
        publishInactive()
    }

    public func setMonitoredKeys(_ keys: [String]) {
        watchedKeys = keys
        refreshSnapshot()
    }

    func devAdded(_ iterator: io_iterator_t) {
        var service = IOIteratorNext(iterator)
        while service != 0 {
            var vendorID: Int = 0
            var productID: Int = 0
            var name = "Unknown"
            if let v = IORegistryEntryCreateCFProperty(service, "idVendor" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() {
                vendorID = (v as? Int) ?? 0
            }
            if let p = IORegistryEntryCreateCFProperty(service, "idProduct" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() {
                productID = (p as? Int) ?? 0
            }
            if let n = IORegistryEntryCreateCFProperty(service, "USB Product Name" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
                name = n
            }
            devLock.withLock {
                connectedDevices.append(USBDevice(vendorID: vendorID, productID: productID, name: name))
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        refreshSnapshot()
    }

    func devRemoved(_ iterator: io_iterator_t) {
        var service = IOIteratorNext(iterator)
        while service != 0 {
            var vendorID: Int = 0
            var productID: Int = 0
            if let v = IORegistryEntryCreateCFProperty(service, "idVendor" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() {
                vendorID = (v as? Int) ?? 0
            }
            if let p = IORegistryEntryCreateCFProperty(service, "idProduct" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() {
                productID = (p as? Int) ?? 0
            }
            devLock.withLock {
                connectedDevices.removeAll { $0.vendorID == vendorID && $0.productID == productID }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        refreshSnapshot()
    }

    private func refreshSnapshot() {
        let devices = devLock.withLock { connectedDevices }
        let deviceNames = devices.map { $0.name }
        var readings: [SensorReading] = [
            SensorReading(key: "devices", label: "Connected Devices", value: .strings(deviceNames))
        ]
        for key in watchedKeys {
            let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  let vid = Int(parts[0]),
                  let pid = Int(parts[1]) else { continue }
            let connected = devices.contains { $0.vendorID == vid && $0.productID == pid }
            readings.append(SensorReading(key: key, label: key, value: .boolean(connected)))
        }
        publishSnapshot(readings: readings)
    }
}
