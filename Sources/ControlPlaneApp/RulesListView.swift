import SwiftUI
import AppKit
import ControlPlaneSDK

/// Lists the rules attached to a profile, with controls to add / edit / remove / toggle.
struct RulesListView: View {

    let profile: Profile
    @ObservedObject var store: ControlPlaneStore

    @State private var selectedRuleIDs  = Set<UUID>()
    @State private var showingCreateRule = false
    @State private var editingRule: Rule? = nil

    private var rules: [Rule] { store.rules(for: profile.id) }

    /// The single selected rule, or nil if zero or more than one row is selected.
    private var singleSelection: Rule? {
        guard selectedRuleIDs.count == 1,
              let id = selectedRuleIDs.first
        else { return nil }
        return rules.first { $0.id == id }
    }

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
            CreateRuleView(profile: profile, store: store)
        }
        .sheet(item: $editingRule) { rule in
            CreateRuleView(profile: profile, store: store, existingRule: rule)
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

            TableColumn("") { rule in
                matchIndicator(for: rule)
            }
            .width(20)

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
            if ids.count == 1, let rule = rules.first(where: { ids.contains($0.id) }) {
                Button("Edit Rule") { editingRule = rule }
                Divider()
            }
            Button("Delete", role: .destructive) {
                let toDelete = rules.filter { ids.contains($0.id) }
                Task {
                    for rule in toDelete { await store.deleteRule(rule) }
                    selectedRuleIDs.removeAll()
                }
            }
        }
        // Double-click: sets the NSTableView's doubleAction via an invisible background view.
        .background(
            TableDoubleClickHandler {
                guard let rule = singleSelection else { return }
                editingRule = rule
            }
        )
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

            Button(action: {
                guard let rule = singleSelection else { return }
                editingRule = rule
            }) {
                Image(systemName: "pencil").frame(width: 28, height: 24)
            }
            .buttonStyle(.borderless)
            .disabled(singleSelection == nil)
            .help("Edit selected rule")

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

    /// Small SF-Symbol dot indicating whether this rule is currently matching.
    /// Disabled rules show nothing; enabled rules show green (match) or red (no match).
    /// A dashed circle is shown before the first evaluation result arrives.
    @ViewBuilder
    private func matchIndicator(for rule: Rule) -> some View {
        if !rule.enabled {
            // Disabled rules contribute nothing — don't show a state indicator.
            Color.clear
        } else if let matched = store.ruleMatches[rule.id] {
            Image(systemName: matched ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(matched ? .green : .red)
                .help(matched ? "Rule is currently matching" : "Rule is not matching")
        } else {
            // No evaluation result yet (app just launched or rule just created).
            Image(systemName: "circle.dotted")
                .foregroundStyle(.tertiary)
                .help("Awaiting evaluation")
        }
    }
}

// MARK: - Double-click handler

/// Invisible background view that walks up to the enclosing NSTableView and
/// wires its doubleAction to our closure.
private struct TableDoubleClickHandler: NSViewRepresentable {

    let onDoubleClick: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.onDoubleClick = onDoubleClick
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onDoubleClick = onDoubleClick
        // Schedule on the next run-loop pass so the view is in the hierarchy.
        DispatchQueue.main.async {
            guard let tableView = nsView.enclosingTableView else { return }
            tableView.doubleAction = #selector(Coordinator.handleDoubleClick(_:))
            tableView.target = context.coordinator
        }
    }

    final class Coordinator: NSObject {
        var onDoubleClick: (() -> Void)?

        @objc func handleDoubleClick(_ sender: Any?) {
            onDoubleClick?()
        }
    }
}

private extension NSView {
    /// Walk the superview chain to find the nearest enclosing NSTableView.
    var enclosingTableView: NSTableView? {
        var view: NSView? = superview
        while let v = view {
            if let table = v as? NSTableView { return table }
            view = v.superview
        }
        return nil
    }
}
