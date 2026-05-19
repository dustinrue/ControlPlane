import Foundation
import SystemConfiguration
import ControlPlaneSDK

public final class NetworkLinkSensor: BaseSensor {

    public override var pluginIdentifier: String  { "com.controlplane.sensors.networklink" }
    public override var pluginDisplayName: String { "Network Link" }

    private var store: SCDynamicStore?
    private var rlSource: CFRunLoopSource?

    public override required init() {
        super.init()
    }

    public override func start() async {
        var ctx = SCDynamicStoreContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        store = SCDynamicStoreCreate(
            nil,
            "com.controlplane.networklink" as CFString,
            { _, _, info in
                guard let info else { return }
                Unmanaged<NetworkLinkSensor>.fromOpaque(info).takeUnretainedValue().refreshSnapshot()
            },
            &ctx
        )
        guard let store else { return }
        SCDynamicStoreSetNotificationKeys(
            store,
            nil,
            ["State:/Network/Interface/.*/Link"] as CFArray
        )
        rlSource = SCDynamicStoreCreateRunLoopSource(nil, store, 0)
        if let src = rlSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
        }
        refreshSnapshot()
    }

    public override func stop() async {
        if let src = rlSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .defaultMode)
            rlSource = nil
        }
        store = nil
        publishInactive()
    }

    /// Re-read current link state on demand (e.g. after system wake).
    /// The SCDynamicStore callback fires when keys change, but an explicit
    /// refresh ensures the snapshot is correct before the first callback arrives.
    public override func refresh() async {
        refreshSnapshot()
    }

    private func refreshSnapshot() {
        guard let store else { return }
        let pattern = "State:/Network/Interface/.*/Link" as CFString
        let keys = SCDynamicStoreCopyKeyList(store, pattern) as? [String] ?? []

        let friendlyNames = buildFriendlyInterfaceNames()
        var readings: [SensorReading] = []
        var activeInterfaces: [String] = []

        for key in keys {
            // Key format: "State:/Network/Interface/<iface>/Link"
            let parts = key.split(separator: "/")
            guard parts.count >= 4 else { continue }
            let iface = String(parts[3])
            var isActive = false
            if let val = SCDynamicStoreCopyValue(store, key as CFString) as? [String: Any],
               let active = val["Active"] as? Bool {
                isActive = active
            }
            let label = friendlyNames[iface] ?? iface
            readings.append(SensorReading(key: iface, label: label, value: .boolean(isActive)))
            if isActive { activeInterfaces.append(iface) }
        }
        readings.append(SensorReading(key: "activeInterfaces", label: "Active Interfaces", value: .strings(activeInterfaces)))
        publishSnapshot(readings: readings)
    }
}
