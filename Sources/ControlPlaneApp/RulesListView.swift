import SwiftUI
import ControlPlaneSDK

/// Lists the rules attached to a profile, with controls to add / remove / toggle.
struct RulesListView: View {

    let profile: Profile
    @ObservedObject var store: ControlPlaneStore

    @State private var selectedRuleIDs = Set<UUID>()
    @State private var showingCreateRule = false

    private var rules: [Rule] { store.rules(for: profile.id) }

    var body: some View {
        VStack(spacing: 0) {
            if rules.isEmpty {
                emptyState
            } else {
                ruleTable
            }
            Divider()
            toolbar
        }
        .sheet(isPresented: $showingCreateRule) {
            CreateRuleView(profile: profile, store: store) {
                // nothing extra on save
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No rules for this profile")
                .foregroundStyle(.secondary)
            Button("Add Rule") { showingCreateRule = true }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Table

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

            TableColumn("Name") { rule in
                Text(rule.name).lineLimit(1)
            }

            TableColumn("Sensor") { rule in
                Text(store.snapshot(for: rule.sensorID)?.displayName ?? rule.sensorID)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            TableColumn("Condition") { rule in
                HStack(spacing: 4) {
                    if rule.negate {
                        Text("NOT").font(.caption).foregroundStyle(.orange)
                    }
                    Text(rule.readingKey)
                        .font(.system(.body, design: .monospaced))
                    Text(operatorLabel(rule.operatorID))
                        .foregroundStyle(.secondary)
                    Text(rule.comparand.description)
                        .font(.system(.body, design: .monospaced))
                }
                .lineLimit(1)
            }

            TableColumn("Weight") { rule in
                Text(String(format: "%.1f", rule.weight))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(50)
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            Button("Delete", role: .destructive) {
                let toDelete = rules.filter { ids.contains($0.id) }
                Task {
                    for rule in toDelete {
                        await store.deleteRule(rule)
                    }
                    selectedRuleIDs.removeAll()
                }
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 0) {
            Button(action: { showingCreateRule = true }) {
                Image(systemName: "plus").frame(width: 28, height: 24)
            }
            .buttonStyle(.borderless)
            .help("Add rule")

            Button(action: {
                let toDelete = rules.filter { selectedRuleIDs.contains($0.id) }
                Task {
                    for rule in toDelete { await store.deleteRule(rule) }
                    selectedRuleIDs.removeAll()
                }
            }) {
                Image(systemName: "minus").frame(width: 28, height: 24)
            }
            .buttonStyle(.borderless)
            .disabled(selectedRuleIDs.isEmpty)
            .help("Remove selected rules")

            Spacer()

            Text("\(rules.count) rule\(rules.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.trailing, 8)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func operatorLabel(_ id: String) -> String {
        store.operators.first { $0.id == id }?.label ?? id
    }
}
