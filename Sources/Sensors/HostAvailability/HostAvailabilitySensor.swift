import Foundation
import ControlPlaneSDK
import os

private let haLogger = Logger(subsystem: "com.controlplane.app", category: "HostAvailabilitySensor")

/// Sensor that detects whether local-network devices are present by browsing
/// Bonjour/mDNS service advertisements — the same mechanism that causes devices
/// to appear in Finder's Network sidebar.
///
/// A device is considered "present" (reading = true) when it is advertising at
/// least one of the browsed service types. The reading key and display label are
/// the device's friendly Bonjour name (e.g. "My NAS", "Dustin's MacBook Pro").
///
/// Because detection is event-driven (NetServiceBrowser callbacks), there is no
/// polling and no TCP probing. Discovery begins in start() and updates are pushed
/// to the rule engine via onSnapshotChanged whenever a device appears or disappears.
public final class HostAvailabilitySensor: BaseSensor, DynamicKeySensor {

    public override var pluginIdentifier: String  { "com.controlplane.sensors.hostavailability" }
    public override var pluginDisplayName: String { "Host Availability" }

    // Service types to browse — covers the broadest set of Finder-visible devices.
    private let serviceTypes = [
        "_smb._tcp",          // NAS appliances, Windows shares, most file servers
        "_afpovertcp._tcp",   // Apple File Protocol (older Macs, NAS)
        "_device-info._tcp",  // Most Apple devices
        "_workstation._tcp",  // macOS workstations via mDNSResponder
        "_ssh._tcp",          // Linux servers, Raspberry Pi, etc.
    ]

    // One browser per service type — all run on RunLoop.main.
    private var browsers: [String: NetServiceBrowser] = [:]

    // Discovered device names keyed by service type, under lock.
    private let lock = NSLock()
    private var discovered: [String: Set<String>] = [:]   // serviceType → device names
    private var monitoredKeys: Set<String> = []

    public override required init() {
        super.init()
    }

    // MARK: - SensorPlugin

    public override func start() async {
        haLogger.info("HostAvailabilitySensor starting — browsing \(self.serviceTypes.count) service types")
        await MainActor.run {
            for type_ in serviceTypes {
                let browser = NetServiceBrowser()
                browser.delegate = self
                browser.searchForServices(ofType: type_, inDomain: "local.")
                browsers[type_] = browser
            }
        }
        publishSnapshot()
    }

    public override func stop() async {
        await MainActor.run {
            for browser in browsers.values { browser.stop() }
            browsers.removeAll()
        }
        lock.withLock {
            discovered.removeAll()
            monitoredKeys.removeAll()
        }
        publishInactive()
        haLogger.info("HostAvailabilitySensor stopped")
    }

    // MARK: - DynamicKeySensor

    /// Called by the backend after each rule change with the set of device names
    /// referenced by enabled rules. Only affects which names are reported as
    /// monitored — browsing continues for all service types regardless.
    public func setMonitoredKeys(_ keys: [String]) {
        lock.withLock { monitoredKeys = Set(keys) }
        publishSnapshot()
    }

    // MARK: - Snapshot

    private func publishSnapshot() {
        let (allPresent, monitored) = lock.withLock {
            let present = discovered.values.reduce(into: Set<String>()) { $0.formUnion($1) }
            return (present, monitoredKeys)
        }

        var readings: [SensorReading] = []

        // Emit a reading for every currently-present device (powers the UI picker).
        for name in allPresent.sorted() {
            readings.append(SensorReading(key: name, label: name, value: .boolean(true)))
        }

        // For monitored keys that are NOT present, emit false so the rule engine
        // sees the correct state even when the device is offline.
        for name in monitored where !allPresent.contains(name) {
            readings.append(SensorReading(key: name, label: name, value: .boolean(false)))
        }

        publishSnapshot(readings: readings)
    }
}

// MARK: - NetServiceBrowserDelegate

extension HostAvailabilitySensor: NetServiceBrowserDelegate {

    public func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didFind service: NetService,
        moreComing: Bool
    ) {
        // Find which service type this browser is responsible for.
        guard let type_ = browsers.first(where: { $0.value === browser })?.key else { return }
        let name = service.name
        haLogger.debug("[\(type_, privacy: .public)] found: \(name, privacy: .public)")
        lock.withLock { discovered[type_, default: []].insert(name) }
        if !moreComing { publishSnapshot() }
    }

    public func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didRemove service: NetService,
        moreComing: Bool
    ) {
        guard let type_ = browsers.first(where: { $0.value === browser })?.key else { return }
        let name = service.name
        haLogger.debug("[\(type_, privacy: .public)] removed: \(name, privacy: .public)")
        lock.withLock { discovered[type_]?.remove(name) }
        if !moreComing { publishSnapshot() }
    }

    public func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didNotSearch errorDict: [String: NSNumber]
    ) {
        let type_ = browsers.first(where: { $0.value === browser })?.key ?? "?"
        haLogger.error("[\(type_, privacy: .public)] search error: \(errorDict, privacy: .public)")
    }
}
