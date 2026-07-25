import SwiftUI
import ControlPlaneSDK

/// Global action library tab.
/// Each row shows the action type, name, and which profiles it is linked to.
/// Actions are defined here; assignment to profiles happens on the Profiles tab.
struct ActionsTabView: View {

    @ObservedObject var store: ControlPlaneStore
    @State private var selectedActionIDs = Set<UUID>()
    @State private var showingCreateAction = false
    @State private var editingAction: Action? = nil
    @State private var deletingAction: Action? = nil

    private var singleSelection: Action? {
        guard selectedActionIDs.count == 1, let id = selectedActionIDs.first else { return nil }
        return store.actions.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            if store.actions.isEmpty {
                emptyState
            } else {
                actionTable
            }
            Divider()
            toolbar
        }
        .sheet(isPresented: $showingCreateAction) {
            CreateOrEditActionView(store: store)
        }
        .sheet(item: $editingAction) { action in
            CreateOrEditActionView(store: store, existingAction: action)
        }
        .alert(
            "Delete Action",
            isPresented: Binding(get: { deletingAction != nil }, set: { if !$0 { deletingAction = nil } })
        ) {
            Button("Cancel", role: .cancel) { deletingAction = nil }
            Button("Delete", role: .destructive) {
                if let a = deletingAction {
                    Task { await store.deleteAction(a) }
                    deletingAction = nil
                }
            }
        } message: {
            if let a = deletingAction {
                let usedBy = store.profileNames(linkedTo: a)
                if usedBy.isEmpty {
                    Text("Delete \"\(a.name)\"?")
                } else {
                    Text("\"\(a.name)\" is assigned to \(usedBy). Deleting it will remove it from those profiles.")
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.badge.clock")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No actions yet")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Create reusable actions here, then assign them to profiles.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("New Action") { showingCreateAction = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Table

    private var actionTable: some View {
        Table(store.actions, selection: $selectedActionIDs) {
            TableColumn("Type") { action in
                if let typeInfo = store.actionType(for: action.actionPluginID) {
                    Text(typeInfo.displayName)
                        .lineLimit(1)
                } else {
                    Text(action.actionPluginID)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .width(min: 120, ideal: 150)

            TableColumn("Name") { action in
                Text(action.name)
                    .lineLimit(1)
                    .fontWeight(action.enabled ? .regular : .light)
                    .foregroundStyle(action.enabled ? .primary : .secondary)
            }

            TableColumn("Used By") { action in
                let names = store.profileNames(linkedTo: action)
                Text(names.isEmpty ? "—" : names)
                    .foregroundStyle(names.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
            }
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            if ids.count == 1, let action = store.actions.first(where: { ids.contains($0.id) }) {
                Button("Edit \"\(action.name)\"") { editingAction = action }
                Divider()
                Button("Delete \"\(action.name)\"", role: .destructive) { deletingAction = action }
            } else if ids.count > 1 {
                Button("Delete \(ids.count) Actions", role: .destructive) {
                    let toDelete = store.actions.filter { ids.contains($0.id) }
                    Task { for a in toDelete { await store.deleteAction(a) } }
                    selectedActionIDs.removeAll()
                }
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 0) {
            Button { showingCreateAction = true } label: {
                Image(systemName: "plus").frame(width: 28, height: 24)
            }
            .buttonStyle(.borderless)
            .help("New action")

            Button {
                if let a = singleSelection { deletingAction = a }
            } label: {
                Image(systemName: "minus").frame(width: 28, height: 24)
            }
            .buttonStyle(.borderless)
            .disabled(singleSelection == nil)
            .help("Delete selected action")

            Button {
                if let a = singleSelection { editingAction = a }
            } label: {
                Image(systemName: "pencil").frame(width: 28, height: 24)
            }
            .buttonStyle(.borderless)
            .disabled(singleSelection == nil)
            .help("Edit selected action")

            Spacer()

            Text("\(store.actions.count) action\(store.actions.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.trailing, 8)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }
}

// MARK: - Create / Edit Action Sheet

struct CreateOrEditActionView: View {

    @ObservedObject var store: ControlPlaneStore
    var existingAction: Action?

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var selectedPluginID: String
    @State private var config: [String: String]
    @State private var enabled: Bool

    init(store: ControlPlaneStore, existingAction: Action? = nil) {
        self.store = store
        self.existingAction = existingAction
        _name             = State(initialValue: existingAction?.name ?? "")
        _selectedPluginID = State(initialValue: existingAction?.actionPluginID ?? "")
        _config           = State(initialValue: existingAction?.config ?? [:])
        _enabled          = State(initialValue: existingAction?.enabled ?? true)
    }

    private var isEditing: Bool { existingAction != nil }
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !selectedPluginID.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            Text(isEditing ? "Edit Action" : "New Action")
                .font(.headline)
                .padding()

            Divider()

            Form {
                Section {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)

                    Picker("Type", selection: $selectedPluginID) {
                        Text("Choose…").tag("").disabled(true)
                        ForEach(store.actionTypes) { type in
                            Text(type.displayName).tag(type.id)
                        }
                    }
                    .onChange(of: selectedPluginID) { _ in
                        // Clear config when type changes to avoid stale keys.
                        if existingAction == nil || selectedPluginID != existingAction?.actionPluginID {
                            config = [:]
                        }
                    }

                    Toggle("Enabled", isOn: $enabled)
                } header: {
                    Text("General")
                }

                if !selectedPluginID.isEmpty {
                    ActionConfigForm(pluginID: selectedPluginID, config: $config)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "Save" : "Create") {
                    let trimmedName = name.trimmingCharacters(in: .whitespaces)
                    if let existing = existingAction {
                        Task {
                            await store.updateAction(existing, name: trimmedName,
                                                     actionPluginID: selectedPluginID,
                                                     config: config, enabled: enabled)
                        }
                    } else {
                        Task {
                            await store.createAction(name: trimmedName,
                                                     actionPluginID: selectedPluginID,
                                                     config: config)
                        }
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 460)
    }
}
