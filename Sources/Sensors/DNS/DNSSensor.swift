import Foundation
import SystemConfiguration
import ControlPlaneSDK

public final class DNSSensor: BaseSensor {

    public override var pluginIdentifier: String  { "com.controlplane.sensors.dns" }
    public override var pluginDisplayName: String { "DNS" }

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
            "com.controlplane.dns" as CFString,
            { _, _, info in
                guard let info else { return }
                Unmanaged<DNSSensor>.fromOpaque(info).takeUnretainedValue().refreshSnapshot()
            },
            &ctx
        )
        guard let store else { return }
        SCDynamicStoreSetNotificationKeys(
            store,
            ["State:/Network/Global/DNS"] as CFArray,
            nil
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

    private func refreshSnapshot() {
        guard let store else { return }
        var searchDomains: [String] = []
        var servers: [String] = []

        if let val = SCDynamicStoreCopyValue(store, "State:/Network/Global/DNS" as CFString) as? [String: Any] {
            searchDomains = val["SearchDomains"] as? [String] ?? []
            servers = val["ServerAddresses"] as? [String] ?? []
        }

        let primary = searchDomains.first ?? ""
        publishSnapshot(readings: [
            SensorReading(key: "searchDomains",  label: "Search Domains",  value: .strings(searchDomains)),
            SensorReading(key: "servers",        label: "DNS Servers",     value: .strings(servers)),
            SensorReading(key: "primaryDomain",  label: "Primary Domain",  value: .string(primary)),
        ])
    }
}
