import SwiftUI
import ControlPlaneSDK

/// Modal sheet for quickly creating a rule from a live sensor reading.
/// The sensor, key, operator and comparand are pre-filled and shown read-only.
/// The user only needs to choose a profile, optionally negate, and set weight.
struct QuickCreateRuleView: View {

    let snapshot: SensorSnapshot
    let reading: SensorReading
    @ObservedObject var store: ControlPlaneStore

    @Environment(\.dismiss) private var dismiss

    @State private var selectedProfileID: UUID?
    @State private var weight: Double = 1.0
    @State private var negate: Bool = false
    @State private var showingNewProfile = false
    @State private var newProfileName = ""

    private var selectedProfile: Profile? {
        store.profiles.first { $0.id == selectedProfileID }
    }

    private var rulePreview: String {
        let neg   = negate ? "NOT " : ""
        let label = snapshot.displayName
        let key   = reading.label.isEmpty ? reading.key : reading.label
        let val   = reading.value.description
        return "\(label) → \(key) \(neg)equals \(val)  (weight \(String(format: "%.1f", weight)))"
    }

    private var isValid: Bool { selectedProfileID != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Create Rule")
                    .font(.headline)
                Text("\(snapshot.displayName) → \(reading.label.isEmpty ? reading.key : reading.label) equals \(reading.value.description)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding()

            Divider()

            Form {
                // Profile picker + inline new-profile form
                Section {
                    if store.profiles.isEmpty {
                        Text("No profiles yet — create one below.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Profile", selection: $selectedProfileID) {
                            Text("Choose…").tag(Optional<UUID>.none)
                            ForEach(store.profiles) { profile in
                                Text(profile.name).tag(Optional(profile.id))
                            }
                        }
                    }

                    if showingNewProfile {
                        HStack {
                            TextField("Profile name", text: $newProfileName)
                                .textFieldStyle(.roundedBorder)
                            Button("Cancel") {
                                showingNewProfile = false
                                newProfileName = ""
                            }
                            .buttonStyle(.bordered)
                            Button("Create") {
                                let name = newProfileName.trimmingCharacters(in: .whitespaces)
                                guard !name.isEmpty else { return }
                                Task {
                                    await store.createProfile(name: name)
                                    selectedProfileID = store.profiles.last?.id
                                }
                                showingNewProfile = false
                                newProfileName = ""
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newProfileName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    } else {
                        Button("+ New Profile…") { showingNewProfile = true }
                            .buttonStyle(.borderless)
                            .foregroundStyle(Color.accentColor)
                    }
                } header: {
                    Text("Profile")
                }

                Section {
                    Toggle(isOn: $negate) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Negate")
                            Text("Rule matches when the value does NOT equal \(reading.value.description)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    LabeledContent("Confidence Weight") {
                        HStack {
                            Slider(value: $weight, in: 0.1...2.0, step: 0.1)
                            Text(String(format: "%.1f", weight))
                                .monospacedDigit()
                                .frame(width: 32)
                        }
                    }
                } header: {
                    Text("Options")
                }

                Section {
                    Text(rulePreview)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Preview")
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save Rule") {
                    guard let profile = selectedProfile else { return }
                    let key   = reading.label.isEmpty ? reading.key : reading.key
                    let name  = "\(snapshot.displayName) \(reading.label.isEmpty ? reading.key : reading.label)"
                    Task {
                        await store.createRule(
                            name: name,
                            profileID: profile.id,
                            sensorID: snapshot.sensorID,
                            readingKey: key,
                            operatorID: defaultOperatorID,
                            comparand: reading.value,
                            weight: weight,
                            negate: negate
                        )
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 460)
        .onAppear {
            // Pre-select first profile if only one exists.
            if store.profiles.count == 1 { selectedProfileID = store.profiles.first?.id }
        }
    }

    /// Pick the most appropriate operator for the reading value type.
    private var defaultOperatorID: String {
        switch reading.value {
        case .boolean:           return "equals"
        case .string:            return "equals"
        case .number:            return "equals"
        case .strings:           return "contains"
        }
    }
}
