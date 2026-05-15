import Foundation
import IOKit
import IOKit.pwr_mgt
import ControlPlaneSDK

// MARK: - C-level interest callback

private func clamshellCallback(
    _ refCon: UnsafeMutableRawPointer?,
    _ service: io_service_t,
    _ messageType: UInt32,
    _ messageArgument: UnsafeMutableRawPointer?
) {
    guard let ptr = refCon else { return }
    let kIOPMMessageClamshellStateChange: UInt32 = 0x00000200
    guard messageType == kIOPMMessageClamshellStateChange else { return }
    let sensor = Unmanaged<LaptopLidSensor>.fromOpaque(ptr).takeUnretainedValue()
    let closed = (Int(bitPattern: messageArgument) & 1) != 0
    sensor.updateLidClosed(closed)
}

// MARK: - Sensor

public final class LaptopLidSensor: BaseSensor {

    public override var pluginIdentifier: String  { "com.controlplane.sensors.laptoplid" }
    public override var pluginDisplayName: String { "Laptop Lid" }

    private var notifyPort: IONotificationPortRef?
    private var notificationObject: io_object_t = 0
    private var lidClosed = false

    public override required init() {
        super.init()
    }

    public override class func isApplicable() -> Bool {
        let rootDomain = IORegistryEntryFromPath(kIOMainPortDefault, "IOService:/IOResources/IOPMrootDomain")
        guard rootDomain != 0 else { return false }
        defer { IOObjectRelease(rootDomain) }
        if let val = IORegistryEntryCreateCFProperty(
            rootDomain,
            "AppleClamshellExists" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Bool {
            return val
        }
        return false
    }

    public override func start() async {
        notifyPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let port = notifyPort else { return }
        if let rl = IONotificationPortGetRunLoopSource(port) {
            CFRunLoopAddSource(CFRunLoopGetMain(), rl.takeUnretainedValue(), .defaultMode)
        }

        let rootDomain = IORegistryEntryFromPath(kIOMainPortDefault, "IOService:/IOResources/IOPMrootDomain")
        guard rootDomain != 0 else { return }
        defer { IOObjectRelease(rootDomain) }

        IOServiceAddInterestNotification(
            port,
            rootDomain,
            kIOGeneralInterest,
            clamshellCallback,
            Unmanaged.passUnretained(self).toOpaque(),
            &notificationObject
        )

        // Read initial state
        if let val = IORegistryEntryCreateCFProperty(
            rootDomain,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Bool {
            lidClosed = val
        }
        refreshSnapshot()
    }

    public override func stop() async {
        if notificationObject != 0 {
            IOObjectRelease(notificationObject)
            notificationObject = 0
        }
        if let port = notifyPort {
            if let rl = IONotificationPortGetRunLoopSource(port) {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), rl.takeUnretainedValue(), .defaultMode)
            }
            IONotificationPortDestroy(port)
            notifyPort = nil
        }
        publishInactive()
    }

    func updateLidClosed(_ closed: Bool) {
        lidClosed = closed
        refreshSnapshot()
    }

    private func refreshSnapshot() {
        publishSnapshot(readings: [
            SensorReading(key: "lidClosed", label: "Lid Closed", value: .boolean(lidClosed))
        ])
    }
}
