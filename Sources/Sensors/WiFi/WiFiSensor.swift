import Foundation
import CoreWLAN
import CoreLocation
import Network
import ControlPlaneSDK
import os

private let wifiLogger = Logger(subsystem: "com.controlplane.app", category: "WiFiSensor")

/// Sensor that observes the current Wi-Fi connection state using CoreWLAN.
///
/// Always emits: connected, SSID, BSSID, RSSI, security type.
/// Network scan (visible_networks): only runs when a rule references the
/// "visible_networks" reading key. The backend calls `setMonitoredKeys(_:)`
/// after each rule change; if no rule uses "visible_networks" the scan loop
/// is stopped entirely, eliminating unnecessary background wakeups.
/// When scanning is active and the device is connected, `scanWhileConnected`
/// controls whether scans continue (default false).
///
/// SSID and BSSID require Location Services permission on macOS 10.15+. The sensor
/// requests authorization automatically on start via CLLocationManager. If permission
/// is denied, ssid/bssid are emitted as empty strings.
public final class WiFiSensor: NSObject, SensorPlugin, ConfigurableSensor, PushSensor, DynamicKeySensor {
    public var pluginIdentifier: String { "com.controlplane.sensors.wifi" }
    public var pluginDisplayName: String { "Wi-Fi" }
    public var pluginVersion: String { "1.0.0" }
    public var pluginCategory: String { "sensor" }

    /// When false (default), network scanning is suppressed while connected.
    /// Only relevant when scanning is active (i.e. a rule references visible_networks).
    public var scanWhileConnected: Bool = false

    /// Injected by SensorCoordinator. Called after every snapshot update.
    public var onSnapshotChanged: (@Sendable () -> Void)?

    /// True only when at least one enabled rule references the "visible_networks" key.
    /// Controlled by setMonitoredKeys(_:) — do not set directly.
    private var scanEnabled: Bool = false

    private let client = CWWiFiClient.shared()
    private var interface: CWInterface?
    private var observers: [NSObjectProtocol] = []
    private var scanTask: Task<Void, Never>?
    private var pathMonitor: NWPathMonitor?

    // CLLocationManager is required to trigger the macOS location permission
    // prompt and to unlock SSID/BSSID access from CoreWLAN.
    private var locationManager: CLLocationManager?

    // NSLock guards both _snapshot and _visibleNetworks.
    private let lock = NSLock()
    private var _snapshot: SensorSnapshot
    private var _visibleNetworks: [(ssid: String, rssi: Int)] = []

    public override required init() {
        _snapshot = SensorSnapshot(
            sensorID: "com.controlplane.sensors.wifi",
            displayName: "Wi-Fi",
            readings: [],
            isActive: false
        )
        super.init()
    }

    public static func isApplicable() -> Bool {
        !(CWWiFiClient.shared().interfaces() ?? []).isEmpty
    }

    public func start() async {
        requestLocationAuthorization()
        interface = client.interface()
        subscribeToEvents()
        startPathMonitor()
        // Scan loop is NOT started here. It starts only when setMonitoredKeys(_:)
        // is called with a key set that includes "visible_networks". This avoids
        // unnecessary background wakeups when no rule uses that reading.
        refreshSnapshot()
    }

    public func stop() async {
        scanTask?.cancel()
        scanTask = nil
        pathMonitor?.cancel()
        pathMonitor = nil
        try? client.stopMonitoringAllEvents()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
        interface = nil
        locationManager?.delegate = nil
        locationManager = nil
        lock.withLock {
            _visibleNetworks = []
            _snapshot = SensorSnapshot(
                sensorID: pluginIdentifier,
                displayName: pluginDisplayName,
                readings: [],
                isActive: false
            )
        }
    }

    // MARK: - Location authorization

    private func requestLocationAuthorization() {
        // CLLocationManager must be created on a thread that has a run loop
        // (typically the main thread). Delegate callbacks also arrive there.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let mgr = CLLocationManager()
            mgr.delegate = self
            self.locationManager = mgr   // must hold a strong reference

            switch mgr.authorizationStatus {
            case .authorizedAlways:
                wifiLogger.debug("[WiFiSensor] Location: already authorized (always)")
                // Already authorized — re-fetch interface so CoreWLAN picks up
                // the auth state and starts returning SSID/BSSID.
                self.interface = self.client.interface()
                self.refreshSnapshot()
            case .notDetermined:
                wifiLogger.debug("[WiFiSensor] Location: requesting always authorization")
                mgr.requestAlwaysAuthorization()
            case .denied, .restricted:
                wifiLogger.debug("[WiFiSensor] Location: denied/restricted — SSID/BSSID will be empty")
            @unknown default:
                wifiLogger.debug("[WiFiSensor] Location: unknown status (\(mgr.authorizationStatus.rawValue))")
            }
        }
    }

    public func currentSnapshot() async -> SensorSnapshot {
        lock.withLock { _snapshot }
    }

    public func refresh() async {
        // Re-fetch the interface in case the CWWiFiClient singleton cached
        // authorization state from before location permission was granted.
        interface = client.interface()
        refreshSnapshot()
        await runScanIfNeeded()
    }

    // MARK: - Scan loop

    private func startScanLoop() {
        scanTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.runScanIfNeeded()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    // MARK: - DynamicKeySensor

    /// Called by the backend after every rule change.
    /// Starts the scan loop when any rule references "visible_networks";
    /// stops it (and clears stale results) when no rule does.
    public func setMonitoredKeys(_ keys: [String]) {
        let needsScan = keys.contains("visible_networks")
        guard needsScan != scanEnabled else { return }
        scanEnabled = needsScan

        if scanEnabled {
            wifiLogger.debug("[WiFiSensor] visible_networks referenced by a rule — starting scan loop")
            startScanLoop()
        } else {
            wifiLogger.debug("[WiFiSensor] no rules reference visible_networks — stopping scan loop")
            scanTask?.cancel()
            scanTask = nil
            // Clear any stale scan results from the snapshot.
            let changed = lock.withLock {
                let had = !_visibleNetworks.isEmpty
                _visibleNetworks = []
                return had
            }
            if changed { refreshSnapshot() }
        }
    }

    private func runScanIfNeeded() async {
        guard scanEnabled else { return }
        guard let iface = interface else { return }
        let connected = iface.serviceActive()

        guard !connected || scanWhileConnected else {
            // Connected and scanning disabled: clear any stale scan results.
            let changed = lock.withLock {
                let had = !_visibleNetworks.isEmpty
                _visibleNetworks = []
                return had
            }
            if changed { refreshSnapshot() }
            return
        }

        wifiLogger.debug("[WiFiSensor] starting network scan (connected=\(connected), scanWhileConnected=\(self.scanWhileConnected))")
        do {
            let networks = try iface.scanForNetworks(withName: nil)
            let sorted = networks
                .compactMap { n -> (String, Int)? in
                    guard let ssid = n.ssid, !ssid.isEmpty else { return nil }
                    return (ssid, n.rssiValue)
                }
                .sorted { $0.1 > $1.1 }   // strongest signal first
            wifiLogger.debug("[WiFiSensor] scan found \(sorted.count) network(s)")
            lock.withLock { _visibleNetworks = sorted }
        } catch {
            wifiLogger.debug("[WiFiSensor] scanForNetworks failed: \(error.localizedDescription)")
            lock.withLock { _visibleNetworks = [] }
        }
        refreshSnapshot()
    }

    // MARK: - Snapshot

    private func subscribeToEvents() {
        let events: [CWEventType] = [.ssidDidChange, .bssidDidChange, .linkDidChange, .modeDidChange]
        for event in events { try? client.startMonitoringEvent(with: event) }

        // The notification names are deprecated as API entry points but remain the only
        // Swift-accessible notification bridge for CWWiFiClient on macOS 14.
        //
        // IMPORTANT: use object: nil (not object: client).  On macOS 12+, CoreWLAN
        // posts these notifications with the CWInterface as the object — not the
        // CWWiFiClient — so filtering by client silently drops every notification.
        let notificationNames: [Notification.Name] = [
            .CWSSIDDidChange, .CWBSSIDDidChange, .CWLinkDidChange, .CWModeDidChange,
        ]
        for name in notificationNames {
            let observer = NotificationCenter.default.addObserver(
                forName: name, object: nil, queue: nil
            ) { [weak self] _ in
                guard let self else { return }
                self.refreshSnapshot()
                Task { await self.runScanIfNeeded() }
            }
            observers.append(observer)
        }
    }

    /// Start an NWPathMonitor watching the WiFi interface type.
    ///
    /// NWPathMonitor is the modern, reliable API for detecting network-path
    /// changes. It fires immediately with the current state and again whenever
    /// the WiFi path changes (connect, disconnect, interface goes down).
    /// This supplements the CoreWLAN notifications, which are unreliable on
    /// macOS 12+ because they are posted with the CWInterface as the object
    /// rather than the CWWiFiClient.
    private func startPathMonitor() {
        let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
        monitor.pathUpdateHandler = { [weak self] _ in
            // pathUpdateHandler fires on the monitor queue; dispatch to main
            // so refreshSnapshot() can safely access the CWInterface property.
            DispatchQueue.main.async { [weak self] in
                self?.refreshSnapshot()
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))
        pathMonitor = monitor
    }

    private func refreshSnapshot() {
        guard let iface = interface else { return }

        var readings: [SensorReading] = []

        let connected = iface.serviceActive()
        readings.append(SensorReading(key: "connected", label: "Connected", value: .boolean(connected)))

        // CoreWLAN requires both location permission AND the
        // com.apple.developer.networking.wifi-info entitlement (macOS 14+) to
        // return SSID/BSSID.  Ad-hoc-signed builds lack that entitlement, so
        // fall back to `networksetup` which reads from system prefs directly.
        let ssid  = iface.ssid()  ?? (connected ? ssidFromNetworkSetup() : nil) ?? ""
        let bssid = iface.bssid() ?? ""
        readings.append(SensorReading(key: "ssid",  label: "SSID",  value: .string(ssid)))
        readings.append(SensorReading(key: "bssid", label: "BSSID", value: .string(bssid)))

        if connected {
            readings.append(SensorReading(
                key: "rssi", label: "RSSI (dBm)", value: .number(Double(iface.rssiValue()))
            ))
            readings.append(SensorReading(
                key: "security", label: "Security", value: .string(securityLabel(iface.security()))
            ))
        }

        let visible = lock.withLock { _visibleNetworks }
        if !visible.isEmpty {
            let entries = visible.map { "\($0.ssid) (\($0.rssi) dBm)" }
            readings.append(SensorReading(
                key: "visible_networks", label: "Visible Networks", value: .strings(entries)
            ))
        }

        let snap = SensorSnapshot(
            sensorID: pluginIdentifier,
            displayName: pluginDisplayName,
            readings: readings,
            isActive: true
        )
        lock.withLock { _snapshot = snap }
        onSnapshotChanged?()
    }

    // MARK: - ConfigurableSensor

    public func options() -> [SensorOptionDescriptor] {
        [
            SensorOptionDescriptor(
                key: "scanWhileConnected",
                label: "Scan while connected",
                description: "Scan for nearby networks even when already connected to one. " +
                             "Always enabled when disconnected.",
                value: .bool(scanWhileConnected)
            ),
        ]
    }

    public func setOption(key: String, value: SensorOptionValue) throws {
        switch key {
        case "scanWhileConnected":
            guard case .bool(let b) = value else {
                throw CPError.invalidData("scanWhileConnected requires a bool value")
            }
            scanWhileConnected = b
        default:
            throw CPError.invalidData("Unknown option '\(key)' for WiFiSensor")
        }
    }

    // MARK: - Fallback SSID via networksetup

    /// Reads the current SSID using `networksetup -getairportnetwork <interface>`.
    /// This works without the com.apple.developer.networking.wifi-info entitlement.
    /// Returns nil if the interface name is unknown, the network has no SSID, or
    /// the tool is unavailable.
    private func ssidFromNetworkSetup() -> String? {
        guard let ifaceName = interface?.interfaceName else { return nil }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        proc.arguments = ["-getairportnetwork", ifaceName]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()   // silence errors
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return nil
        }
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        // Output format: "Current Wi-Fi Network: <SSID>"
        // When not associated: "You are not associated with an AirPort network."
        guard let range = output.range(of: "Current Wi-Fi Network: ") else { return nil }
        let ssid = String(output[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return ssid.isEmpty ? nil : ssid
    }

    // MARK: - Security label

    private func securityLabel(_ security: CWSecurity) -> String {
        switch security {
        case .none:               return "None"
        case .WEP:                return "WEP"
        case .wpaPersonal:        return "WPA Personal"
        case .wpaPersonalMixed:   return "WPA Personal Mixed"
        case .wpa2Personal:       return "WPA2 Personal"
        case .personal:           return "Personal"
        case .dynamicWEP:         return "Dynamic WEP"
        case .wpaEnterprise:      return "WPA Enterprise"
        case .wpaEnterpriseMixed: return "WPA Enterprise Mixed"
        case .wpa2Enterprise:     return "WPA2 Enterprise"
        case .enterprise:         return "Enterprise"
        case .wpa3Personal:       return "WPA3 Personal"
        case .wpa3Enterprise:     return "WPA3 Enterprise"
        case .wpa3Transition:     return "WPA3 Transition"
        case .OWE:                return "OWE"
        case .oweTransition:      return "OWE Transition"
        case .unknown:            return "Unknown"
        @unknown default:         return "Unknown"
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WiFiSensor: CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        wifiLogger.debug("[WiFiSensor] Location authorization changed: \(status.rawValue)")
        switch status {
        case .authorizedAlways:
            // Re-fetch the interface — CWWiFiClient caches the auth state and
            // will now return SSID/BSSID correctly.
            interface = client.interface()
            refreshSnapshot()
            Task { await self.runScanIfNeeded() }
        case .denied, .restricted:
            wifiLogger.debug("[WiFiSensor] Location denied — SSID/BSSID will remain empty")
            refreshSnapshot()
        default:
            break
        }
    }
}
