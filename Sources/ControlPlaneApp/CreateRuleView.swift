import SwiftUI
import AppKit
import ControlPlaneSDK

/// Sheet for creating a new rule on a profile.
///
/// Sensor → reading key → operator → comparand → weight → name.
///
/// Dynamic sensors (FilePresence, RunningApplication, HostAvailability, USB)
/// don't emit readings until rules reference them. For those sensors the
/// reading key is entered as free text (with a Browse button for FilePresence).
struct CreateRuleView: View {

    let profile: Profile
    @ObservedObject var store: ControlPlaneStore
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var ruleName        = ""
    @State private var sensorID        = ""
    @State private var readingKey      = ""
    @State private var operatorID      = ""
    @State private var comparandString = ""
    @State private var weight          = 1.0
    @State private var negate          = false

    // MARK: - Derived

    private var isDynamic: Bool {
        store.dynamicSensorIDs.contains(sensorID)
    }

    private var isFilePresence: Bool {
        sensorID == "com.controlplane.sensors.filepresence"
    }

    private var selectedSnapshot: SensorSnapshot? {
        store.snapshot(for: sensorID)
    }

    private var selectedReading: SensorReading? {
        guard !isDynamic else { return nil }
        return selectedSnapshot?.readings.first { $0.key == readingKey }
    }

    /// The ObservationValue type string for the current reading.
    private var valueType: String {
        if let r = selectedReading { return store.valueType(r.value) }
        // Dynamic sensors always emit booleans (file exists, app running, host reachable…)
        if isDynamic { return "boolean" }
        return "string"
    }

    private var availableOperators: [OperatorDescriptor] {
        store.operators(for: valueType)
    }

    private var canSave: Bool {
        !sensorID.isEmpty
            && !readingKey.trimmingCharacters(in: .whitespaces).isEmpty
            && !operatorID.isEmpty
            && !comparandString.isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("New Rule")
                .font(.headline)

            Form {
                sensorSection
                readingKeySection
                if !readingKey.trimmingCharacters(in: .whitespaces).isEmpty {
                    conditionSection
                    weightSection
                }
                nameSection
            }
            .formStyle(.grouped)

            if canSave { rulePreview }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add Rule") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 500, height: 580)
        .onAppear { seedInitialSensor() }
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
            .onChange(of: sensorID) { _ in resetBelowSensor() }
        } header: { Text("Sensor") }
    }

    @ViewBuilder
    private var readingKeySection: some View {
        if !sensorID.isEmpty {
            Section {
                if isDynamic {
                    dynamicKeyField
                } else if let snap = selectedSnapshot {
                    staticKeyPicker(snap)
                }
            } header: { Text("Reading") }
        }
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

    @ViewBuilder
    private var comparandField: some View {
        switch valueType {
        case "boolean":
            Picker("Value", selection: $comparandString) {
                Text("true  (exists / running / reachable)").tag("true")
                Text("false (absent / stopped / unreachable)").tag("false")
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

    // MARK: - Rule preview

    private var rulePreview: some View {
        GroupBox("Preview") {
            let neg       = negate ? "NOT " : ""
            let opLabel   = store.operators.first { $0.id == operatorID }?.label ?? operatorID
            let sensorName = store.snapshot(for: sensorID)?.displayName ?? sensorID
            Text(
                "\(neg)\(sensorName) › \(readingKey.isEmpty ? "…" : readingKey)" +
                " \(opLabel) \"\(comparandString)\"" +
                "  (weight \(String(format: "%.1f", weight)))"
            )
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
            return "server.local"
        case "com.controlplane.sensors.usb":
            return "vendorID:productID  e.g. 05ac:12a8"
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
            return "Hostname or IP address to ping."
        case "com.controlplane.sensors.usb":
            return "USB vendor and product ID in hex, colon-separated."
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
