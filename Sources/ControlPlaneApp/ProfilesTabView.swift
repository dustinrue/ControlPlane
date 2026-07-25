import SwiftUI
import ControlPlaneSDK

/// Three-panel Profiles tab:
///   Panel 1 — profile list (~1/3 width)
///   Panel 2 — profile detail: name, threshold, exclusive, confidence badge, rules list
///   Panel 3 — action assignment: all global actions grouped by trigger with checkboxes
struct ProfilesTabView: View {

    @ObservedObject var store: ControlPlaneStore
    @State private var selectedProfileID: UUID?
    @State private var showingCreateProfile = false

    private var selectedProfile: Profile? {
        store.profiles.first { $0.id == selectedProfileID }
    }

    var body: some View {
        HSplitView {
            // Panel 1 — profile list
            profileList
                .frame(minWidth: 200, maxWidth: 280)

            // Panel 2 — profile detail + rules
            if let profile = selectedProfile {
                ProfileDetailPanel(profile: profile, store: store)
                    .id(profile.id)
                    .frame(minWidth: 320)
            } else {
                emptySelection
            }

            // Panel 3 — action assignment checkboxes
            if let profile = selectedProfile {
                ProfileActionsPanel(profile: profile, store: store)
                    .id(profile.id)
                    .frame(minWidth: 220, maxWidth: 300)
            } else {
                Color.clear
                    .frame(minWidth: 220, maxWidth: 300)
            }
        }
        .sheet(isPresented: $showingCreateProfile) {
            CreateProfileView { name, threshold, exclusive in
                Task {
                    await store.createProfile(name: name, confidenceThreshold: threshold, exclusive: exclusive)
                    selectedProfileID = store.profiles.last?.id
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptySelection: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.2")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(store.profiles.isEmpty ? "Add a profile to get started" : "Select a profile")
                .foregroundStyle(.secondary)
            if store.profiles.isEmpty {
                Button("Add Profile") { showingCreateProfile = true }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Panel 1: Profile list

    private var profileList: some View {
        VStack(spacing: 0) {
            List(store.profiles, id: \.id, selection: $selectedProfileID) { profile in
                profileRow(profile)
                    .contextMenu {
                        Button("Delete Profile", role: .destructive) {
                            Task {
                                await store.deleteProfile(profile)
                                if selectedProfileID == profile.id { selectedProfileID = nil }
                            }
                        }
                    }
            }
            Divider()
            HStack(spacing: 0) {
                Button { showingCreateProfile = true } label: {
                    Image(systemName: "plus").frame(width: 28, height: 24)
                }
                .buttonStyle(.borderless)

                Button {
                    guard let p = selectedProfile else { return }
                    Task {
                        await store.deleteProfile(p)
                        selectedProfileID = nil
                    }
                } label: {
                    Image(systemName: "minus").frame(width: 28, height: 24)
                }
                .buttonStyle(.borderless)
                .disabled(selectedProfile == nil)

                Spacer()
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func profileRow(_ profile: Profile) -> some View {
        let active = store.isActive(profile.id)
        let conf   = store.currentConfidence(for: profile.id)
        let threshold = profile.confidenceThreshold

        HStack(spacing: 6) {
            Circle()
                .fill(active ? Color.green : Color.secondary.opacity(0.3))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.name)
                    .fontWeight(active ? .semibold : .regular)
                    .lineLimit(1)
                Text(String(format: "%.2f / %.2f", conf, threshold))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 1)
    }
}

// MARK: - Panel 2: Profile detail + rules

/// Middle panel: editable profile settings at the top, live rules list below.
struct ProfileDetailPanel: View {

    let profile: Profile
    @ObservedObject var store: ControlPlaneStore

    @State private var editName: String
    @State private var editThreshold: Double
    @State private var editExclusive: Bool
    @State private var showingCreateRule = false
    @State private var editingRule: Rule? = nil
    @State private var selectedRuleIDs = Set<UUID>()

    init(profile: Profile, store: ControlPlaneStore) {
        self.profile = profile
        self.store = store
        _editName      = State(initialValue: profile.name)
        _editThreshold = State(initialValue: profile.confidenceThreshold)
        _editExclusive = State(initialValue: profile.exclusive)
    }

    private var rules: [Rule] { store.rules(for: profile.id) }
    private var isActive: Bool { store.isActive(profile.id) }
    private var singleSelection: Rule? {
        guard selectedRuleIDs.count == 1, let id = selectedRuleIDs.first else { return nil }
        return rules.first { $0.id == id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            profileSettings
            Divider()
            rulesSection
        }
        .sheet(isPresented: $showingCreateRule) {
            CreateRuleView(profile: profile, store: store)
        }
        .sheet(item: $editingRule) { rule in
            CreateRuleView(profile: profile, store: store, existingRule: rule)
        }
    }

    // MARK: - Profile settings

    private var profileSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Name + save button
            HStack {
                Text("Name")
                    .foregroundStyle(.secondary)
                    .frame(width: 72, alignment: .trailing)
                TextField("Profile name", text: $editName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { saveIfChanged() }
                if editName != profile.name || editThreshold != profile.confidenceThreshold {
                    Button("Save") { saveIfChanged() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }

            // Threshold slider
            HStack {
                Text("Threshold")
                    .foregroundStyle(.secondary)
                    .frame(width: 72, alignment: .trailing)
                Slider(value: $editThreshold, in: 0.1...5.0, step: 0.1)
                Text(String(format: "%.1f", editThreshold))
                    .monospacedDigit()
                    .frame(width: 32)
            }

            // Exclusive + confidence badge
            HStack {
                Text("")
                    .frame(width: 72)
                Toggle("Exclusive", isOn: $editExclusive)
                    .onChange(of: editExclusive) { _ in saveIfChanged() }
                Spacer()
                confidenceBadge
            }
        }
        .padding()
    }

    private var confidenceBadge: some View {
        let current   = store.currentConfidence(for: profile.id)
        let threshold = profile.confidenceThreshold
        let fraction  = threshold > 0 ? current / threshold : 0
        let color: Color = isActive ? .green : fraction >= 0.5 ? .orange : .secondary

        return HStack(spacing: 4) {
            Circle()
                .fill(isActive ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 8, height: 8)
            Text(String(format: "%.2f / %.2f", current, threshold))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .help("Current confidence / activation threshold")
    }

    // MARK: - Rules

    private var rulesSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Rules")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                Spacer()
            }
            Divider()
            if rules.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No rules for this profile")
                        .foregroundStyle(.secondary)
                    Button("Add Rule") { showingCreateRule = true }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ruleTable
            }
            Divider()
            ruleToolbar
        }
    }

    private var ruleTable: some View {
        Table(rules, selection: $selectedRuleIDs) {
            TableColumn("") { rule in
                Toggle("", isOn: Binding(
                    get: { rule.enabled },
                    set: { enabled in Task { await store.setRuleEnabled(rule, enabled: enabled) } }
                ))
                .labelsHidden()
                .toggleStyle(.checkbox)
            }
            .width(24)

            TableColumn("") { rule in
                let matched = store.ruleMatches[rule.id]
                Image(systemName: matched == true ? "checkmark.circle.fill"
                                : matched == false ? "xmark.circle" : "circle.dotted")
                    .foregroundStyle(matched == true ? .green : matched == false ? .red : .secondary)
                    .help(matched == true ? "Matches" : matched == false ? "Does not match" : "Not yet evaluated")
            }
            .width(20)

            TableColumn("Rule") { rule in
                Text(rule.name).lineLimit(1)
            }

            TableColumn("Weight") { rule in
                Text(String(format: "%.1f", rule.weight))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(52)
        }
    }

    private var ruleToolbar: some View {
        HStack(spacing: 0) {
            Button { showingCreateRule = true } label: {
                Image(systemName: "plus").frame(width: 28, height: 24)
            }
            .buttonStyle(.borderless)
            .help("Add rule")

            Button {
                let toDelete = rules.filter { selectedRuleIDs.contains($0.id) }
                Task {
                    for r in toDelete { await store.deleteRule(r) }
                    selectedRuleIDs.removeAll()
                }
            } label: {
                Image(systemName: "minus").frame(width: 28, height: 24)
            }
            .buttonStyle(.borderless)
            .disabled(selectedRuleIDs.isEmpty)
            .help("Remove selected rules")

            Button {
                if let rule = singleSelection { editingRule = rule }
            } label: {
                Image(systemName: "pencil").frame(width: 28, height: 24)
            }
            .buttonStyle(.borderless)
            .disabled(singleSelection == nil)
            .help("Edit rule")

            Spacer()

            Text("\(rules.count) rule\(rules.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.trailing, 8)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }

    private func saveIfChanged() {
        let trimmed = editName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        Task {
            await store.updateProfile(
                profile, name: trimmed,
                confidenceThreshold: editThreshold,
                exclusive: editExclusive
            )
        }
    }
}

// MARK: - Panel 3: Action assignment checkboxes

/// Right panel: all global actions grouped by On Activate / On Deactivate.
/// Checking a row links that action to the profile for that trigger; unchecking unlinks it.
struct ProfileActionsPanel: View {

    let profile: Profile
    @ObservedObject var store: ControlPlaneStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Actions")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            Divider()

            if store.actions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bolt.slash")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No actions defined")
                        .foregroundStyle(.secondary)
                    Text("Add actions on the Actions tab, then assign them here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        actionGroup(trigger: .onActivate, label: "On Activate")
                        Divider().padding(.vertical, 4)
                        actionGroup(trigger: .onDeactivate, label: "On Deactivate")
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    @ViewBuilder
    private func actionGroup(trigger: ActionTrigger, label: String) -> some View {
        Text(label)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 2)

        ForEach(store.actions) { action in
            let linked = store.link(profileID: profile.id, actionID: action.id, trigger: trigger) != nil
            HStack(spacing: 8) {
                Toggle("", isOn: Binding(
                    get: { linked },
                    set: { isOn in
                        Task {
                            if isOn {
                                await store.linkAction(action, to: profile, trigger: trigger)
                            } else if let existing = store.link(profileID: profile.id, actionID: action.id, trigger: trigger) {
                                await store.unlinkAction(existing)
                            }
                        }
                    }
                ))
                .labelsHidden()
                .toggleStyle(.checkbox)

                VStack(alignment: .leading, spacing: 1) {
                    Text(action.name)
                        .lineLimit(1)
                    if let typeInfo = store.actionType(for: action.actionPluginID) {
                        Text(typeInfo.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
    }
}

// MARK: - Create Profile Sheet

struct CreateProfileView: View {
    let onSave: (String, Double, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var threshold = 1.0
    @State private var exclusive = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("New Profile")
                .font(.headline)

            Form {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                LabeledContent("Confidence Threshold") {
                    HStack {
                        Slider(value: $threshold, in: 0.1...5.0, step: 0.1)
                        Text(String(format: "%.1f", threshold))
                            .frame(width: 36, alignment: .trailing)
                            .monospacedDigit()
                    }
                }

                Toggle("Exclusive (deactivates other profiles)", isOn: $exclusive)
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    onSave(name, threshold, exclusive)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}
