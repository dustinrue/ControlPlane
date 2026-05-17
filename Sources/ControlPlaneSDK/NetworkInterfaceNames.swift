import SystemConfiguration

/// Builds a mapping of BSD interface name (e.g. `"en0"`) to a user-friendly
/// display label (e.g. `"Wi-Fi"`), using the localised names that macOS shows
/// in System Settings → Network.
///
/// When two interfaces share the same localised name (e.g. two Thunderbolt
/// Ethernet adapters), the BSD name is appended in parentheses so the user
/// can tell them apart: `"Ethernet (en2)"`.
///
/// Interfaces with no localised name (loopback, VPN tunnels, etc.) are
/// represented by their BSD name unchanged.
///
/// Both `IPAddressSensor` and `NetworkLinkSensor` call this at snapshot refresh
/// time to populate `SensorReading.label` with friendly names while leaving
/// `SensorReading.key` as the raw BSD name so existing rules are unaffected.
public func buildFriendlyInterfaceNames() -> [String: String] {
    let ifaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] ?? []

    // First pass: collect bsdName → localised display name.
    var raw: [(bsd: String, friendly: String)] = []
    for iface in ifaces {
        guard let bsd = SCNetworkInterfaceGetBSDName(iface) as? String else { continue }
        let friendly = SCNetworkInterfaceGetLocalizedDisplayName(iface) as? String ?? bsd
        raw.append((bsd: bsd, friendly: friendly))
    }

    // Find friendly names that appear more than once.
    var counts: [String: Int] = [:]
    for entry in raw { counts[entry.friendly, default: 0] += 1 }

    var result: [String: String] = [:]
    for entry in raw {
        if counts[entry.friendly]! > 1 {
            result[entry.bsd] = "\(entry.friendly) (\(entry.bsd))"
        } else {
            result[entry.bsd] = entry.friendly
        }
    }
    return result
}
