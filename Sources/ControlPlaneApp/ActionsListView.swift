import SwiftUI
import ControlPlaneSDK

/// Lists the actions attached to a profile, with controls to add / remove / toggle.
struct ActionsListView: View {

    let profile: Profile
    @ObservedObject var store: ControlPlaneStore

    @State private var selectedActionIDs = Set<UUID>()
    @State private var showingCreateAction = false

    private var actions: [ProfileAction] { store.legacyActions(for: profile.id) }

    var body: some View {
        VStack(spacing: 0) {
            if actions.isEmpty {
                emptyState
            } else {
                actionTable
            }
            Divider()
            toolbar
        }
        .sheet(isPresented: $showingCreateAction) {
            CreateActionView(profile: profile, store: store) {}
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bolt.badge.clock")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No actions for this profile")
                .foregroundStyle(.secondary)
            Button("Add Action") { showingCreateAction = true }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Table

    private var actionTable: some View {
        Table(actions, selection: $selectedActionIDs) {
            TableColumn("") { action in
                Toggle("", isOn: Binding(
                    get: { action.enabled },
                    set: { enabled in Task { await store.setProfileActionEnabled(action, enabled: enabled) } }
                ))
                .labelsHidden()
                .toggleStyle(.checkbox)
            }
            .width(24)

            TableColumn("Type") { action in
                Text(store.actionType(for: action.actionPluginID)?.displayName ?? action.actionPluginID)
                    .lineLimit(1)
            }

            TableColumn("Trigger") { action in
                Text(action.trigger == .onActivate ? "On Activate" : "On Deactivate")
                    .foregroundStyle(action.trigger == .onActivate ? .green : .orange)
            }
            .width(110)

            TableColumn("Config") { action in
                Text(configSummary(action))
                    .foregroundStyle(.secondary)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
            }
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            Button("Delete", role: .destructive) {
                let toDelete = actions.filter { ids.contains($0.id) }
                Task {
                    for a in toDelete { await store.deleteProfileAction(a) }
                    selectedActionIDs.removeAll()
                }
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 0) {
            Button(action: { showingCreateAction = true }) {
                Image(systemName: "plus").frame(width: 28, height: 24)
            }
            .buttonStyle(.borderless)
            .help("Add action")

            Button(action: {
                let toDelete = actions.filter { selectedActionIDs.contains($0.id) }
                Task {
                    for a in toDelete { await store.deleteProfileAction(a) }
                    selectedActionIDs.removeAll()
                }
            }) {
                Image(systemName: "minus").frame(width: 28, height: 24)
            }
            .buttonStyle(.borderless)
            .disabled(selectedActionIDs.isEmpty)
            .help("Remove selected actions")

            Spacer()

            Text("\(actions.count) action\(actions.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.trailing, 8)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func configSummary(_ action: ProfileAction) -> String {
        action.config
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "  ")
    }
}
