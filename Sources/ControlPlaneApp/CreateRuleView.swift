import SwiftUI
import AppKit
import CoreWLAN
import ControlPlaneSDK

/// Sheet for creating or editing a rule on a profile.
///
/// Pass `existingRule` to open in edit mode; omit it (nil) for create mode.
///
/// Dynamic sensors (FilePresence, RunningApplication, HostAvailability, USB)
/// don't emit readings until rules reference them. For those sensors the
/// reading key is entered as free text (with a Browse button for FilePresence).
///
/// Bluetooth is special: it IS dynamic but emits per-MAC readings for every
/// paired device. Those readings are shown as a device picker with a live
/// connected/disconnected indicator instead of a free-text MAC address field.
struct CreateRuleView: View {

    let profile: Profile
    @ObservedObject var store: ControlPlaneStore
    /// When non-nil the sheet operates in edit mode, pre-populating all fields.
    let existingRule: Rule?
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var ruleName        = ""
    @State private var sensorID        = ""
    @State private var readingKey      = ""
    @State private var operatorID      = ""
    @State private var comparandString = ""
    @State private var weight          = 1.0
    @State private var negate          = false
    @State private var ruleEnabled     = true

    private var isEditing: Bool { existingRule != nil }

    init(
        profile: Profile,
        store: ControlPlaneStore,
        existingRule: Rule? = nil,
        onSave: @escaping () -> Void = {}
    ) {
        self.profile      = profile
        self.store        = store
        self.existingRule = existingRule
        self.onSave       = onSave

        // Pre-populate @State from the existing rule.
        if let r = existingRule {
            _ruleName        = State(initialValue: r.name)
            _sensorID        = State(initialValue: r.sensorID)
            _readingKey      = State(initialValue: r.readingKey)
            _operatorID      = State(initialValue: r.operatorID)
            _comparandString = State(initialValue: Self.comparandToString(r.comparand))
            _weight          = State(initialValue: r.weight)
            _negate          = State(initialValue: r.negate)
            _ruleEnabled     = State(initialValue: r.enabled)
        }
    }

    /// Convert an ObservationValue back to its editable string representation.
    private static func comparandToString(_ value: ObservationValue) -> String {
        switch value {
        case .boolean(let b): return b ? "true" : "false"
        case .number(let n):
            return n.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(n)) : String(n)
        case .strings(let arr): return arr.joined(separator: ", ")
        case .string(let s): return s
        }
    }

    // MARK: - Derived

    private var isDynamic: Bool {
        store.dynamicSensorIDs.contains(sensorID)
    }

    private var isFilePresence: Bool {
        sensorID == "com.controlplane.sensors.filepresence"
    }

    private var isBluetooth: Bool {
        sensorID == "com.controlplane.sensors.bluetooth"
    }

    private var isRunningApplication: Bool {
        sensorID == "com.controlplane.sensors.runningapplication"
    }

    private var isBonjourSensor: Bool {
        sensorID == "com.controlplane.sensors.hostavailability"
    }

    private var isUSB: Bool {
        sensorID == "com.controlplane.sensors.usb"
    }

    /// True when the user has picked a specific USB device (readingKey is a
    /// vendorID:productID hex key, not the "devices" summary key).
    private var isUSBDeviceRule: Bool {
        isUSB && !readingKey.isEmpty && readingKey != "devices"
    }

    private var isWiFi: Bool {
        sensorID == "com.controlplane.sensors.wifi"
    }

    /// True when the user is building a "connected to network X" WiFi rule —
    /// i.e. the reading key has been locked to "ssid" by the network picker.
    private var isWiFiSSIDRule: Bool {
        isWiFi && readingKey == "ssid"
    }

    /// Binding that maps the `negate` flag to the user-facing
    /// "Connected" / "Disconnected" selection.
    private var wifiConnectionBinding: Binding<String> {
        Binding(
            get: { negate ? "disconnected" : "connected" },
            set: { negate = ($0 == "disconnected") }
        )
    }

    // MARK: - WiFi scan state

    @State private var scannedSSIDs: [String] = []
    @State private var isScanning: Bool = false

    /// All device names currently discovered by HostAvailabilitySensor, sorted.
    private var discoveredBonjourDevices: [String] {
        guard isBonjourSensor else { return [] }
        return (selectedSnapshot?.readings.map(\.label) ?? []).sorted()
    }

    /// All regular user-facing applications currently running, sorted by display name.
    private var runningUserApps: [(name: String, bundleID: String)] {
        NSWorkspace.shared.runningApplications
            .compactMap { app -> (String, String)? in
                guard app.activationPolicy == .regular,
                      let name = app.localizedName,
                      let bid  = app.bundleIdentifier else { return nil }
                return (name, bid)
            }
            .sorted { $0.0 < $1.0 }
    }

    /// Per-MAC readings from the Bluetooth snapshot (excludes the "devices" and "powered" keys).
    private var bluetoothDeviceReadings: [SensorReading] {
        guard isBluetooth, let snap = selectedSnapshot else { return [] }
        return snap.readings.filter { $0.key != "devices" && $0.key != "powered" }
    }

    private var selectedSnapshot: SensorSnapshot? {
        store.snapshot(for: sensorID)
    }

    private var selectedReading: SensorReading? {
        // Bluetooth and other dynamic sensors: look up by key in snapshot
        if isDynamic {
            return selectedSnapshot?.readings.first { $0.key == readingKey }
        }
        return selectedSnapshot?.readings.first { $0.key == readingKey }
    }

    /// The ObservationValue type string for the current reading.
    private var valueType: String {
        if let r = selectedReading { return store.valueType(r.value) }
        // All current dynamic sensors emit booleans
        if isDynamic { return "boolean" }
        // When editing an existing rule whose reading is not currently present
        // (e.g. a mounted volume that is unmounted, or a USB device not connected),
        // preserve the comparand type from the stored rule rather than falling back
        // to "string" — a type mismatch causes equals() to return false at eval time.
        if let existing = existingRule { return store.valueType(existing.comparand) }
        return "string"
    }

    private var availableOperators: [OperatorDescriptor] {
        store.operators(for: valueType)
    }

    private var canSave: Bool {
        guard !sensorID.isEmpty,
              !readingKey.trimmingCharacters(in: .whitespaces).isEmpty,
              !comparandString.isEmpty else { return false }
        // For WiFi SSID and USB device rules the operator is always "equals" and is
        // seeded automatically — don't gate saving on the operatorID being set.
        if isWiFiSSIDRule || isUSBDeviceRule { return true }
        return !operatorID.isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(isEditing ? "Edit Rule" : "New Rule")
                .font(.headline)

            Form {
                sensorSection
                readingKeySection
                if !readingKey.trimmingCharacters(in: .whitespaces).isEmpty {
                    if isWiFiSSIDRule || isUSBDeviceRule {
                        wifiConditionSection
                    } else {
                        conditionSection
                    }
                    weightSection
                }
                nameSection
                if isEditing {
                    Section {
                        Toggle("Enabled", isOn: $ruleEnabled)
                    } header: { Text("Status") }
                }
            }
            .formStyle(.grouped)

            if canSave { rulePreview }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "Save Changes" : "Add Rule") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 500, height: isEditing ? 620 : 580)
        // Only seed sensor when creating; editing starts fully pre-populated.
        .onAppear {
            if !isEditing { seedInitialSensor() }
            // Scan for WiFi networks whenever this sheet opens for a WiFi rule.
            if sensorID == "com.controlplane.sensors.wifi" {
                Task { await scanForWiFiNetworks() }
            }
            // Refresh USB snapshot so the picker shows devices connected right now.
            if sensorID == "com.controlplane.sensors.usb" {
                Task { await store.refreshSnapshots() }
            }
        }
    }

    // MARK: - Sections

    private var sensorSection: some View {
        Section {
            Picker("Sensor", selection: $sensorID) {
                Text("Choose…").tag("")
                ForEach(store.snapshots.sorted(by: { $0.displayName < $1.displayName }), id: \.sensorID) { snap in
                    HStack {
                        Text(snap.displayName)
                        if store.dynamicSensorIDs.contains(snap.sensorID) {
                            Text("(dynamic)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .tag(snap.sensorID)
                }
            }
            .onChange(of: sensorID) { _ in
                resetBelowSensor()
                if sensorID == "com.controlplane.sensors.wifi" {
                    Task { await scanForWiFiNetworks() }
                }
                if sensorID == "com.controlplane.sensors.usb" {
                    Task { await store.refreshSnapshots() }
                }
            }
        } header: { Text("Sensor") }
    }

    @ViewBuilder
    private var readingKeySection: some View {
        if !sensorID.isEmpty {
            Section {
                if isBluetooth {
                    bluetoothDevicePicker
                } else if isWiFi {
                    wifiNetworkPicker
                } else if isRunningApplication {
                    runningApplicationPicker
                } else if isBonjourSensor {
                    bonjourDevicePicker
                } else if isUSB {
                    usbDevicePicker
                } else if isDynamic {
                    dynamicKeyField
                } else if let snap = selectedSnapshot {
                    staticKeyPicker(snap)
                }
            } header: { Text("Reading") }
        }
    }

    /// Picker showing all paired Bluetooth devices with a live connected/disconnected indicator.
    @ViewBuilder
    private var bluetoothDevicePicker: some View {
        if bluetoothDeviceReadings.isEmpty {
            Text("No paired Bluetooth devices found")
                .foregroundStyle(.secondary)
                .font(.callout)
        } else {
            Picker("Device", selection: $readingKey) {
                Text("Choose…").tag("")
                ForEach(bluetoothDeviceReadings, id: \.key) { reading in
                    let isConnected = reading.value == .boolean(true)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isConnected ? Color.green : Color.secondary.opacity(0.4))
                            .frame(width: 8, height: 8)
                        Text(reading.label)
                        Text(reading.key)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(isConnected ? "Connected" : "Not connected")
                            .font(.caption)
                            .foregroundStyle(isConnected ? .green : .secondary)
                    }
                    .tag(reading.key)
                }
            }
            .onChange(of: readingKey) { _ in
                resetBelowKey()
                comparandString = "true"
                seedOperator()
            }

            if !readingKey.isEmpty {
                let device = bluetoothDeviceReadings.first { $0.key == readingKey }
                let isConnected = device?.value == .boolean(true)
                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isConnected ? Color.green : Color.secondary.opacity(0.4))
                            .frame(width: 8, height: 8)
                        Text(isConnected ? "Currently connected" : "Not currently connected")
                            .foregroundStyle(isConnected ? .primary : .secondary)
                    }
                }
            }
        }
    }

    /// Picker of currently running regular (user-facing) applications.
    /// The rule's readingKey is the bundle identifier; we show the localised app name.
    @ViewBuilder
    private var runningApplicationPicker: some View {
        let apps = runningUserApps
        if apps.isEmpty {
            Text("No user applications are currently running")
                .foregroundStyle(.secondary)
                .font(.callout)
        } else {
            Picker("Application", selection: $readingKey) {
                Text("Choose…").tag("")
                ForEach(apps, id: \.bundleID) { app in
                    Text(app.name).tag(app.bundleID)
                }
            }
            .onChange(of: readingKey) { _ in
                resetBelowKey()
                if !readingKey.isEmpty {
                    comparandString = "true"
                    seedOperator()
                }
            }
        }

        // Always show the bundle ID — acts as a display label when picked from the list,
        // and as a manual-entry fallback for apps that are not currently running.
        LabeledContent("Bundle ID") {
            TextField("com.apple.safari", text: $readingKey)
                .textFieldStyle(.roundedBorder)
        }
        Text("Only running apps appear in the list above. Type a bundle ID directly for apps that are not currently open.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    /// Picker of Bonjour/mDNS devices currently visible on the local network.
    /// The rule's readingKey is the device's friendly Bonjour name (e.g. "My NAS").
    @ViewBuilder
    private var bonjourDevicePicker: some View {
        let devices = discoveredBonjourDevices
        if devices.isEmpty {
            Text("No Bonjour devices found on the network yet")
                .foregroundStyle(.secondary)
                .font(.callout)
        } else {
            Picker("Device", selection: $readingKey) {
                Text("Choose…").tag("")
                ForEach(devices, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .onChange(of: readingKey) { _ in
                resetBelowKey()
                if !readingKey.isEmpty {
                    comparandString = "true"
                    seedOperator()
                }
            }
        }

        // Manual-entry fallback for devices not currently advertising.
        LabeledContent("Device name") {
            TextField("My NAS", text: $readingKey)
                .textFieldStyle(.roundedBorder)
        }
        Text("Devices appear when they are advertising Bonjour services (same as Finder's Network sidebar). Enter a name manually for devices not currently on the network.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - USB device picker

    /// Per-device readings from the USB snapshot: all connected devices plus any
    /// watched-but-disconnected devices emitted by the sensor.  Excludes the "devices"
    /// summary reading so the picker only shows individual device rows.
    private var usbDeviceReadings: [SensorReading] {
        guard isUSB, let snap = selectedSnapshot else { return [] }
        return snap.readings
            .filter { $0.key != "devices" }
            .sorted { $0.label < $1.label }
    }

    /// Picker showing every connected USB device by its human-readable name.
    /// Selecting a device writes the vendorID:productID key into `readingKey`.
    /// No manual text field — if nothing is connected the picker is shown
    /// disabled with a "No devices connected" placeholder.
    @ViewBuilder
    private var usbDevicePicker: some View {
        let readings = usbDeviceReadings
        Picker("Device", selection: $readingKey) {
            if readings.isEmpty {
                Text("No devices connected").tag("").disabled(true)
            } else {
                Text("Choose…").tag("")
                ForEach(readings, id: \.key) { reading in
                    let isConnected = reading.value == .boolean(true)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isConnected ? Color.green : Color.secondary.opacity(0.4))
                            .frame(width: 8, height: 8)
                        Text(reading.label)
                        Spacer()
                        Text(isConnected ? "Connected" : "Not connected")
                            .font(.caption)
                            .foregroundStyle(isConnected ? .green : .secondary)
                    }
                    .tag(reading.key)
                }
            }
        }
        .disabled(readings.isEmpty)
        .onChange(of: readingKey) { _ in
            resetBelowKey()
            if !readingKey.isEmpty {
                comparandString = "true"
                seedOperator()
            }
        }
        .onAppear {
            // When editing, seed operator so the form is valid immediately.
            if !readingKey.isEmpty && operatorID.isEmpty { seedOperator() }
            if !readingKey.isEmpty && comparandString.isEmpty { comparandString = "true" }
        }

        if !readingKey.isEmpty {
            LabeledContent("Device ID") {
                Text(readingKey)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - WiFi network picker

    /// Picker for the Wi-Fi sensor.
    ///
    /// The rule's readingKey is always "ssid" and the comparand is the selected
    /// network name (e.g. "MyHomeWiFi").  A one-shot CoreWLAN scan is run when
    /// the sheet opens so the user sees nearby networks in a dropdown rather than
    /// having to type an SSID by hand.
    @ViewBuilder
    private var wifiNetworkPicker: some View {
        // SSID currently reported by the live Wi-Fi snapshot.
        let liveSSID: String = {
            guard let r = selectedSnapshot?.readings.first(where: { $0.key == "ssid" }),
                  case .string(let s) = r.value, !s.isEmpty else { return "" }
            return s
        }()
        let isConnected = selectedSnapshot?.readings.first(where: { $0.key == "connected" })?.value
            == .boolean(true)

        // Merge scan results with the live SSID and (when editing) the existing comparand
        // so the picker always shows at least the relevant network even if it is not
        // currently nearby.
        let allNetworks: [String] = {
            var seen = Set<String>()
            var list = scannedSSIDs
            if !liveSSID.isEmpty     { list.append(liveSSID)     }
            if !comparandString.isEmpty { list.append(comparandString) }
            return list.filter { seen.insert($0).inserted }.sorted()
        }()

        if isScanning {
            LabeledContent("Network") {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Scanning for networks…").foregroundStyle(.secondary)
                }
            }
        } else if allNetworks.isEmpty {
            Text("No Wi-Fi networks found. Make sure Wi-Fi is turned on.")
                .foregroundStyle(.secondary)
                .font(.callout)
        } else {
            Picker("Network", selection: $comparandString) {
                Text("Choose…").tag("")
                ForEach(allNetworks, id: \.self) { ssid in
                    HStack(spacing: 6) {
                        if ssid == liveSSID && isConnected {
                            Image(systemName: "wifi")
                                .imageScale(.small)
                                .foregroundStyle(.green)
                        }
                        Text(ssid)
                        if ssid == liveSSID && isConnected {
                            Text("(connected)")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    .tag(ssid)
                }
            }
            .onChange(of: comparandString) { ssid in
                guard !ssid.isEmpty else { return }
                // Lock in the reading key and seed the equals operator so
                // canSave and the preview both reflect the selection.
                readingKey = "ssid"
                if operatorID.isEmpty {
                    operatorID = store.operators(for: "string")
                        .first { $0.id == "equals" }?.id
                        ?? store.operators(for: "string").first?.id ?? ""
                }
            }
            .onAppear {
                // When editing, pre-seed readingKey + operator from the
                // existing comparand so the form is valid immediately.
                if !comparandString.isEmpty {
                    readingKey = "ssid"
                    if operatorID.isEmpty {
                        operatorID = store.operators(for: "string")
                            .first { $0.id == "equals" }?.id
                            ?? store.operators(for: "string").first?.id ?? ""
                    }
                }
            }
        }

        Button(isScanning ? "Scanning…" : "Scan again") {
            Task { await scanForWiFiNetworks() }
        }
        .controlSize(.small)
        .disabled(isScanning)

        Text("Choose the network this rule triggers on. Select \"Connected\" or \"Disconnected\" in the Condition section below.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    /// Run a one-shot CoreWLAN scan and store the discovered SSIDs.
    /// Must be called from an async context; the actual scan runs on a
    /// detached task so it doesn't block the main actor.
    private func scanForWiFiNetworks() async {
        isScanning = true
        let results: [String] = await Task.detached(priority: .userInitiated) {
            // CWWiFiClient.shared() is safe to call off the main thread for
            // the interface lookup; scanForNetworks runs synchronously here.
            let iface = CWWiFiClient.shared().interface()
            guard let iface else { return [] }
            do {
                let networks = try iface.scanForNetworks(withName: nil)
                var seen = Set<String>()
                return networks
                    .compactMap { $0.ssid }
                    .filter { !$0.isEmpty && seen.insert($0).inserted }
                    .sorted()
            } catch {
                return []
            }
        }.value
        scannedSSIDs = results
        isScanning = false
    }

    /// Free-text entry for dynamic sensors (the key IS the path / bundle ID / hostname).
    private var dynamicKeyField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField(dynamicKeyPlaceholder, text: $readingKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: readingKey) { _ in resetBelowKey() }

                if isFilePresence {
                    Button("Browse…") { browseForFile() }
                        .controlSize(.small)
                }
            }
            Text(dynamicKeyHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Picker from the snapshot's known readings (non-dynamic sensors).
    private func staticKeyPicker(_ snap: SensorSnapshot) -> some View {
        Group {
            Picker("Reading", selection: $readingKey) {
                Text("Choose…").tag("")
                ForEach(snap.readings, id: \.key) { r in
                    HStack {
                        Text(r.label)
                        Text("(\(r.key))").font(.caption).foregroundStyle(.secondary)
                    }
                    .tag(r.key)
                }
            }
            .onChange(of: readingKey) { _ in
                resetBelowKey()
                if let r = selectedReading {
                    comparandString = r.value.description
                    operatorID = store.operators(for: store.valueType(r.value)).first?.id ?? ""
                }
            }

            if let r = selectedReading {
                LabeledContent("Current value") {
                    Text(r.value.description)
                        .foregroundStyle(.secondary)
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
    }

    /// Simplified condition section for Wi-Fi SSID rules.
    /// Presents "Connected" / "Disconnected" instead of exposing the
    /// negate flag and operator picker to the user.
    @ViewBuilder
    private var wifiConditionSection: some View {
        Section {
            Picker("State", selection: wifiConnectionBinding) {
                Text("Connected").tag("connected")
                Text("Disconnected").tag("disconnected")
            }
            .pickerStyle(.radioGroup)
        } header: { Text("Condition") }
    }

    @ViewBuilder
    private var conditionSection: some View {
        Section {
            Toggle("Negate (NOT)", isOn: $negate)

            if !availableOperators.isEmpty {
                Picker("Operator", selection: $operatorID) {
                    Text("Choose…").tag("")
                    ForEach(availableOperators) { op in
                        Text("\(op.label)  (\(op.id))").tag(op.id)
                    }
                }
                .onAppear { seedOperator() }
            }

            comparandField
        } header: { Text("Condition") }
    }

    private var weightSection: some View {
        Section {
            LabeledContent("Weight") {
                HStack {
                    Slider(value: $weight, in: 0.1...2.0, step: 0.1)
                    Text(String(format: "%.1f", weight))
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                }
            }
        } header: { Text("Weight") }
    }

    private var nameSection: some View {
        Section {
            TextField("Auto-generated if blank", text: $ruleName)
                .textFieldStyle(.roundedBorder)
        } header: { Text("Name (optional)") }
    }

    // MARK: - Comparand field

    /// Friendly true/false labels for the boolean comparand picker, tailored to each sensor.
    private var booleanLabels: (trueLabel: String, falseLabel: String) {
        switch sensorID {
        case "com.controlplane.sensors.networklink":
            return ("Connected", "Not connected")
        case "com.controlplane.sensors.bluetooth":
            // "powered" key describes the adapter state; MAC keys describe device connections.
            return readingKey == "powered"
                ? ("Powered on", "Powered off")
                : ("Connected", "Not connected")
        case "com.controlplane.sensors.usb":
            return ("Connected", "Not connected")
        case "com.controlplane.sensors.mountedvolume":
            return ("Mounted", "Not mounted")
        case "com.controlplane.sensors.filepresence":
            return ("Present", "Not present")
        case "com.controlplane.sensors.runningapplication":
            return ("Running", "Not running")
        case "com.controlplane.sensors.hostavailability":
            return ("Present", "Not present")
        case "com.controlplane.sensors.screenlock":
            return ("Locked", "Unlocked")
        case "com.controlplane.sensors.laptoplid":
            return ("Closed", "Open")
        case "com.controlplane.sensors.power":
            return ("Yes", "No")
        default:
            return ("true", "false")
        }
    }

    /// Fixed options for string readings whose values come from a closed set.
    /// Returns nil when the reading accepts free-form text.
    private var enumeratedStringOptions: [(label: String, value: String)]? {
        switch (sensorID, readingKey) {
        case ("com.controlplane.sensors.power", "source"):
            return [("AC Power (plugged in)", "ac"),
                    ("Battery (unplugged)",   "battery")]
        default:
            return nil
        }
    }

    @ViewBuilder
    private var comparandField: some View {
        if let options = enumeratedStringOptions {
            // Closed-set string reading — show a radio-style picker instead of a text field.
            Picker("Value", selection: $comparandString) {
                ForEach(options, id: \.value) { opt in
                    Text(opt.label).tag(opt.value)
                }
            }
            .pickerStyle(.radioGroup)
            .onAppear { if comparandString.isEmpty { comparandString = options.first?.value ?? "" } }
        } else {
            switch valueType {
            case "boolean":
                let labels = booleanLabels
                Picker("Value", selection: $comparandString) {
                    Text(labels.trueLabel).tag("true")
                    Text(labels.falseLabel).tag("false")
                }
                .pickerStyle(.radioGroup)
                .onAppear { if comparandString.isEmpty { comparandString = "true" } }

            case "number":
                LabeledContent("Value") {
                    TextField("e.g. 42", text: $comparandString)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)
                }

            default: // string, strings
                LabeledContent("Value") {
                    TextField("e.g. MyWifi", text: $comparandString)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    // MARK: - Rule preview

    private var rulePreviewText: String {
        if isWiFiSSIDRule {
            let state = negate ? "Disconnected from" : "Connected to"
            return "Wi-Fi: \(state) \"\(comparandString)\"" +
                   "  (weight \(String(format: "%.1f", weight)))"
        }
        if isUSBDeviceRule {
            let deviceLabel = selectedSnapshot?.readings.first { $0.key == readingKey }?.label ?? readingKey
            let state = negate ? "Not connected" : "Connected"
            return "USB Device › \(deviceLabel)  \(state)" +
                   "  (weight \(String(format: "%.1f", weight)))"
        }
        let neg        = negate ? "NOT " : ""
        let opLabel    = store.operators.first { $0.id == operatorID }?.label ?? operatorID
        let sensorName = store.snapshot(for: sensorID)?.displayName ?? sensorID
        return "\(neg)\(sensorName) › \(readingKey.isEmpty ? "…" : readingKey)" +
               " \(opLabel) \"\(comparandString)\"" +
               "  (weight \(String(format: "%.1f", weight)))"
    }

    private var rulePreview: some View {
        GroupBox("Preview") {
            Text(rulePreviewText)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Dynamic sensor helpers

    private var dynamicKeyPlaceholder: String {
        switch sensorID {
        case "com.controlplane.sensors.filepresence":
            return "/path/to/file"
        case "com.controlplane.sensors.runningapplication":
            return "com.apple.safari"
        case "com.controlplane.sensors.hostavailability":
            return "My NAS"
        default:
            return "key"
        }
    }

    private var dynamicKeyHint: String {
        switch sensorID {
        case "com.controlplane.sensors.filepresence":
            return "Absolute path to the file or directory to watch."
        case "com.controlplane.sensors.runningapplication":
            return "Bundle identifier of the application (e.g. com.apple.safari)."
        case "com.controlplane.sensors.hostavailability":
            return "Device name as shown in Finder's Network sidebar."
        default:
            return "Reading key for this sensor."
        }
    }

    // MARK: - Browse for file

    private func browseForFile() {
        let panel = NSOpenPanel()
        panel.title = "Choose a file or folder to watch"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            readingKey = url.path
            resetBelowKey()
            // FilePresenceSensor always emits boolean
            comparandString = "true"
            seedOperator()
        }
    }

    // MARK: - State helpers

    private func resetBelowSensor() {
        readingKey = ""
        operatorID = ""
        comparandString = ""
    }

    private func resetBelowKey() {
        operatorID = ""
        comparandString = ""
    }

    private func seedOperator() {
        if operatorID.isEmpty {
            operatorID = availableOperators.first?.id ?? ""
        }
    }

    private func seedInitialSensor() {
        if sensorID.isEmpty, let first = store.snapshots.first {
            sensorID = first.sensorID
        }
    }

    // MARK: - Save

    private func save() {
        let trimmedKey = readingKey.trimmingCharacters(in: .whitespaces)
        let name = ruleName.trimmingCharacters(in: .whitespaces).isEmpty
            ? autoName(key: trimmedKey)
            : ruleName.trimmingCharacters(in: .whitespaces)

        guard let comparand = makeComparand() else { return }

        Task {
            if let existing = existingRule {
                await store.updateRule(
                    existing,
                    name: name,
                    sensorID: sensorID,
                    readingKey: trimmedKey,
                    operatorID: operatorID,
                    comparand: comparand,
                    weight: weight,
                    negate: negate,
                    enabled: ruleEnabled
                )
            } else {
                await store.createRule(
                    name: name,
                    profileID: profile.id,
                    sensorID: sensorID,
                    readingKey: trimmedKey,
                    operatorID: operatorID,
                    comparand: comparand,
                    weight: weight,
                    negate: negate
                )
            }
            onSave()
            dismiss()
        }
    }

    private func autoName(key: String) -> String {
        let sensorName = store.snapshot(for: sensorID)?.displayName ?? sensorID
        let opLabel    = store.operators.first { $0.id == operatorID }?.label ?? operatorID
        let keyShort   = key.count > 40 ? "…" + key.suffix(37) : key
        return "\(sensorName) › \(keyShort) \(opLabel) \(comparandString)"
    }

    private func makeComparand() -> ObservationValue? {
        switch valueType {
        case "boolean":
            return .boolean(comparandString == "true")
        case "number":
            guard let d = Double(comparandString) else { return nil }
            return .number(d)
        case "strings":
            return .strings(
                comparandString
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            )
        default:
            return .string(comparandString)
        }
    }
}

// Make OperatorDescriptor Identifiable for ForEach
extension OperatorDescriptor: Identifiable {}
