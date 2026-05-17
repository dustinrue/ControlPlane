import SwiftUI
import ControlPlaneSDK

/// Sheet for creating a new rule on a profile.
///
/// Sensor → reading key → operator → comparand → weight → name.
struct CreateRuleView: View {

    let profile: Profile
    @ObservedObject var store: ControlPlaneStore
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    // Step-driven state
    @State private var ruleName   = ""
    @State private var sensorID   = ""
    @State private var readingKey = ""
    @State private var operatorID = ""
    @State private var comparandString = ""
    @State private var weight     = 1.0
    @State private var negate     = false

    // Derived
    private var selectedSnapshot: SensorSnapshot? {
        store.snapshot(for: sensorID)
    }
    private var selectedReading: SensorReading? {
        selectedSnapshot?.readings.first { $0.key == readingKey }
    }
    private var valueType: String {
        guard let r = selectedReading else { return "string" }
        return store.valueType(r.value)
    }
    private var availableOperators: [OperatorDescriptor] {
        store.operators(for: valueType)
    }
    private var canSave: Bool {
        !sensorID.isEmpty && !readingKey.isEmpty && !operatorID.isEmpty && !comparandString.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("New Rule")
                .font(.headline)

            Form {
                // --- Rule name ---
                Section {
                    TextField("Rule name (optional)", text: $ruleName)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Name")
                }

                // --- Sensor ---
                Section {
                    Picker("Sensor", selection: $sensorID) {
                        Text("Choose…").tag("")
                        ForEach(store.snapshots.sorted(by: { $0.displayName < $1.displayName }), id: \.sensorID) { snap in
                            Text(snap.displayName).tag(snap.sensorID)
                        }
                    }
                    .onChange(of: sensorID) { _ in
                        readingKey = ""
                        operatorID = ""
                        comparandString = ""
                    }
                } header: {
                    Text("Sensor")
                }

                // --- Reading key ---
                if let snap = selectedSnapshot {
                    Section {
                        Picker("Reading", selection: $readingKey) {
                            Text("Choose…").tag("")
                            ForEach(snap.readings, id: \.key) { reading in
                                HStack {
                                    Text(reading.label)
                                    Text("(\(reading.key))").foregroundStyle(.secondary).font(.caption)
                                }
                                .tag(reading.key)
                            }
                        }
                        .onChange(of: readingKey) { _ in
                            operatorID = ""
                            comparandString = ""
                            // Pre-fill comparand with current value
                            if let r = selectedReading {
                                comparandString = r.value.description
                                // Auto-pick first compatible operator
                                operatorID = store.operators(for: store.valueType(r.value)).first?.id ?? ""
                            }
                        }

                        if let reading = selectedReading {
                            LabeledContent("Current value") {
                                Text(reading.value.description)
                                    .foregroundStyle(.secondary)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    } header: {
                        Text("Reading")
                    }
                }

                // --- Operator + comparand ---
                if !readingKey.isEmpty {
                    Section {
                        Toggle("Negate (NOT)", isOn: $negate)

                        if !availableOperators.isEmpty {
                            Picker("Operator", selection: $operatorID) {
                                Text("Choose…").tag("")
                                ForEach(availableOperators) { op in
                                    Text("\(op.label)  (\(op.id))").tag(op.id)
                                }
                            }
                        }

                        comparandField
                    } header: {
                        Text("Condition")
                    }

                    Section {
                        LabeledContent("Weight") {
                            HStack {
                                Slider(value: $weight, in: 0.1...2.0, step: 0.1)
                                Text(String(format: "%.1f", weight))
                                    .monospacedDigit()
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                    } header: {
                        Text("Weight")
                    }
                }
            }
            .formStyle(.grouped)

            // Summary preview
            if canSave {
                rulePreview
            }

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
        .frame(width: 480, height: 580)
        .onAppear {
            // Auto-select first sensor when opening
            if sensorID.isEmpty, let first = store.snapshots.first {
                sensorID = first.sensorID
            }
        }
    }

    // MARK: - Comparand field

    @ViewBuilder
    private var comparandField: some View {
        switch valueType {
        case "boolean":
            Picker("Value", selection: $comparandString) {
                Text("true").tag("true")
                Text("false").tag("false")
            }
            .pickerStyle(.segmented)
            .onAppear {
                if comparandString.isEmpty { comparandString = "true" }
            }

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

    // MARK: - Preview

    private var rulePreview: some View {
        GroupBox("Preview") {
            let negText  = negate ? "NOT " : ""
            let opLabel  = store.operators.first { $0.id == operatorID }?.label ?? operatorID
            let sensorName = store.snapshot(for: sensorID)?.displayName ?? sensorID
            Text("\(negText)\(sensorName) › \(readingKey) \(opLabel) \"\(comparandString)\"  (weight \(String(format: "%.1f", weight)))")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Save

    private func save() {
        let name = ruleName.trimmingCharacters(in: .whitespaces).isEmpty
            ? autoName()
            : ruleName.trimmingCharacters(in: .whitespaces)

        guard let comparand = makeComparand() else { return }

        Task {
            await store.createRule(
                name: name,
                profileID: profile.id,
                sensorID: sensorID,
                readingKey: readingKey,
                operatorID: operatorID,
                comparand: comparand,
                weight: weight,
                negate: negate
            )
            onSave()
            dismiss()
        }
    }

    private func autoName() -> String {
        let sensorName = store.snapshot(for: sensorID)?.displayName ?? sensorID
        let opLabel = store.operators.first { $0.id == operatorID }?.label ?? operatorID
        return "\(sensorName) \(readingKey) \(opLabel) \(comparandString)"
    }

    private func makeComparand() -> ObservationValue? {
        switch valueType {
        case "boolean":
            return .boolean(comparandString == "true")
        case "number":
            guard let d = Double(comparandString) else { return nil }
            return .number(d)
        case "strings":
            return .strings(comparandString
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty })
        default:
            return .string(comparandString)
        }
    }
}

// Make OperatorDescriptor Identifiable for ForEach
extension OperatorDescriptor: Identifiable {}
