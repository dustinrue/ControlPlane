import Foundation
import SystemConfiguration
import ControlPlaneSDK

public final class IPAddressSensor: BaseSensor {

    public override var pluginIdentifier: String  { "com.controlplane.sensors.ipaddress" }
    public override var pluginDisplayName: String { "IP Address" }

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
            "com.controlplane.ipaddress" as CFString,
            { _, _, info in
                guard let info else { return }
                Unmanaged<IPAddressSensor>.fromOpaque(info).takeUnretainedValue().refreshSnapshot()
            },
            &ctx
        )
        guard let store else { return }
        let patterns = [
            "State:/Network/Interface/.*/IPv4",
            "State:/Network/Interface/.*/IPv6",
        ] as CFArray
        SCDynamicStoreSetNotificationKeys(store, nil, patterns)
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

    private func refreshSnapshot() {
        guard let store else { return }

        let friendlyNames = buildFriendlyInterfaceNames()
        var readings: [SensorReading] = []
        var allAddresses: [String] = []
        var ifaceAddresses: [String: (ipv4: String, ipv6: String)] = [:]

        // IPv4
        let ipv4Keys = SCDynamicStoreCopyKeyList(store, "State:/Network/Interface/.*/IPv4" as CFString) as? [String] ?? []
        for key in ipv4Keys {
            let parts = key.split(separator: "/")
            guard parts.count >= 4 else { continue }
            let iface = String(parts[3])
            if let val = SCDynamicStoreCopyValue(store, key as CFString) as? [String: Any],
               let addrs = val["Addresses"] as? [String], let first = addrs.first {
                ifaceAddresses[iface, default: (ipv4: "", ipv6: "")].ipv4 = first
                allAddresses.append(first)
            }
        }

        // IPv6
        let ipv6Keys = SCDynamicStoreCopyKeyList(store, "State:/Network/Interface/.*/IPv6" as CFString) as? [String] ?? []
        for key in ipv6Keys {
            let parts = key.split(separator: "/")
            guard parts.count >= 4 else { continue }
            let iface = String(parts[3])
            if let val = SCDynamicStoreCopyValue(store, key as CFString) as? [String: Any],
               let addrs = val["Addresses"] as? [String] {
                let nonLinkLocal = addrs.filter { !$0.hasPrefix("fe80") }
                let chosen = nonLinkLocal.first ?? addrs.first ?? ""
                ifaceAddresses[iface, default: (ipv4: "", ipv6: "")].ipv6 = chosen
                if !chosen.isEmpty { allAddresses.append(chosen) }
            }
        }

        for (iface, addrs) in ifaceAddresses {
            let base = friendlyNames[iface] ?? iface
            readings.append(SensorReading(key: "\(iface).ipv4", label: "\(base) (IPv4)", value: .string(addrs.ipv4)))
            readings.append(SensorReading(key: "\(iface).ipv6", label: "\(base) (IPv6)", value: .string(addrs.ipv6)))
        }
        readings.append(SensorReading(key: "allAddresses", label: "All Addresses", value: .strings(allAddresses)))
        publishSnapshot(readings: readings)
    }

}
