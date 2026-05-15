import Foundation
import CoreWLAN
import CoreLocation
import ControlPlaneSDK

/// Sensor that observes the current Wi-Fi connection state using CoreWLAN.
///
/// Always emits: connected, SSID, BSSID, RSSI, security type.
/// Network scan (visible_networks): always runs when not connected; when connected,
/// controlled by `scanWhileConnected` (default false).
///
/// SSID and BSSID require Location Services permission on macOS 10.15+. The sensor
/// requests authorization automatically on start via CLLocationManager. If permission
/// is denied, ssid/bssid are emitted as empty strings.
public final class WiFiSensor: NSObject, SensorPlugin, ConfigurableSensor, PushSensor {
    public var pluginIdentifier: String { "com.controlplane.sensors.wifi" }
    public var pluginDisplayName: String { "Wi-Fi" }
    public var pluginVersion: String { "1.0.0" }
    public var pluginCategory: String { "sensor" }

    /// When false (default), network scanning is suppressed while connected.
    /// Scanning always runs when not connected regardless of this flag.
    public var scanWhileConnected: Bool = false

    /// Injected by SensorCoordinator. Called after every snapshot update.
    public var onSnapshotChanged: (@Sendable () -> Void)?

    private let client = CWWiFiClient.shared()
    private var interface: CWInterface?
    private var observers: [NSObjectProtocol] = []
    private var scanTask: Task<Void, Never>?

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
        startScanLoop()
        refreshSnapshot()
    }

    public func stop() async {
        scanTask?.cancel()
        scanTask = nil
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
                print("[WiFiSensor] Location: already authorized (always)")
                // Already authorized — re-fetch interface so CoreWLAN picks up
                // the auth state and starts returning SSID/BSSID.
                self.interface = self.client.interface()
                self.refreshSnapshot()
            case .notDetermined:
                print("[WiFiSensor] Location: requesting always authorization")
                mgr.requestAlwaysAuthorization()
            case .denied, .restricted:
                print("[WiFiSensor] Location: denied/restricted — SSID/BSSID will be empty")
            @unknown default:
                print("[WiFiSensor] Location: unknown status (\(mgr.authorizationStatus.rawValue))")
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

    private func runScanIfNeeded() async {
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

        print("[WiFiSensor] starting network scan (connected=\(connected), scanWhileConnected=\(scanWhileConnected))")
        do {
            let networks = try iface.scanForNetworks(withName: nil)
            let sorted = networks
                .compactMap { n -> (String, Int)? in
                    guard let ssid = n.ssid, !ssid.isEmpty else { return nil }
                    return (ssid, n.rssiValue)
                }
                .sorted { $0.1 > $1.1 }   // strongest signal first
            print("[WiFiSensor] scan found \(sorted.count) network(s)")
            lock.withLock { _visibleNetworks = sorted }
        } catch {
            print("[WiFiSensor] scanForNetworks failed: \(error.localizedDescription)")
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
        let notificationNames: [Notification.Name] = [
            .CWSSIDDidChange, .CWBSSIDDidChange, .CWLinkDidChange, .CWModeDidChange,
        ]
        for name in notificationNames {
            let observer = NotificationCenter.default.addObserver(
                forName: name, object: client, queue: nil
            ) { [weak self] _ in
                // On link-state change, trigger a scan cycle immediately so visible_networks
                // reflects reality (e.g. just disconnected → start scanning right away).
                guard let self else { return }
                self.refreshSnapshot()
                Task { await self.runScanIfNeeded() }
            }
            observers.append(observer)
        }
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
        print("[WiFiSensor] Location authorization changed: \(status.rawValue)")
        switch status {
        case .authorizedAlways:
            // Re-fetch the interface — CWWiFiClient caches the auth state and
            // will now return SSID/BSSID correctly.
            interface = client.interface()
            refreshSnapshot()
            Task { await self.runScanIfNeeded() }
        case .denied, .restricted:
            print("[WiFiSensor] Location denied — SSID/BSSID will remain empty")
            refreshSnapshot()
        default:
            break
        }
    }
}
