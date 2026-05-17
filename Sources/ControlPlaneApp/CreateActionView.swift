import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ControlPlaneSDK

/// Sheet for creating a new action on a profile.
///
/// Picks action type → trigger → fills in config fields from configDescriptors.
/// Config keys that represent file-system paths get a Browse button in addition
/// to the text field; the panel is scoped appropriately for each action type.
struct CreateActionView: View {

    let profile: Profile
    @ObservedObject var store: ControlPlaneStore
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var actionTypeID = ""
    @State private var trigger: ActionTrigger = .onActivate
    @State private var configValues: [String: String] = [:]

    private var selectedType: ActionTypeInfo? {
        store.actionTypes.first { $0.id == actionTypeID }
    }

    private var canSave: Bool {
        guard let t = selectedType else { return false }
        return t.configDescriptors
            .filter { $0.required }
            .allSatisfy { desc in
                let v = configValues[desc.key] ?? ""
                return !v.trimmingCharacters(in: .whitespaces).isEmpty
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("New Action")
                .font(.headline)

            Form {
                Section {
                    Picker("Action Type", selection: $actionTypeID) {
                        Text("Choose…").tag("")
                        ForEach(store.actionTypes.sorted(by: { $0.displayName < $1.displayName })) { t in
                            Text(t.displayName).tag(t.id)
                        }
                    }
                    .onChange(of: actionTypeID) { _ in
                        configValues = [:]
                        if let t = selectedType {
                            for desc in t.configDescriptors {
                                if let def = desc.defaultValue {
                                    configValues[desc.key] = def
                                }
                            }
                        }
                    }
                } header: { Text("Type") }

                Section {
                    Picker("Trigger", selection: $trigger) {
                        Text("On Activate").tag(ActionTrigger.onActivate)
                        Text("On Deactivate").tag(ActionTrigger.onDeactivate)
                    }
                    .pickerStyle(.segmented)
                } header: { Text("Trigger") }

                if let t = selectedType, !t.configDescriptors.isEmpty {
                    Section {
                        ForEach(t.configDescriptors, id: \.key) { desc in
                            configField(desc)
                        }
                    } header: { Text("Configuration") }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add Action") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 480, height: 440)
        .onAppear {
            if actionTypeID.isEmpty,
               let first = store.actionTypes.sorted(by: { $0.displayName < $1.displayName }).first {
                actionTypeID = first.id
                for desc in first.configDescriptors {
                    if let def = desc.defaultValue { configValues[desc.key] = def }
                }
            }
        }
    }

    // MARK: - Config field

    @ViewBuilder
    private func configField(_ desc: ActionConfigDescriptor) -> some View {
        LabeledContent(desc.label) {
            VStack(alignment: .leading, spacing: 4) {
                if let panelConfig = pathPanelConfig(for: desc.key) {
                    // Path field: text box + Browse button side by side
                    HStack(spacing: 6) {
                        TextField(
                            desc.defaultValue ?? "/path/to/file",
                            text: Binding(
                                get: { configValues[desc.key] ?? "" },
                                set: { configValues[desc.key] = $0 }
                            )
                        )
                        .textFieldStyle(.roundedBorder)

                        Button("Browse…") {
                            browse(config: panelConfig, key: desc.key)
                        }
                        .controlSize(.small)
                    }
                } else {
                    TextField(
                        desc.defaultValue ?? (desc.required ? "Required" : "Optional"),
                        text: Binding(
                            get: { configValues[desc.key] ?? "" },
                            set: { configValues[desc.key] = $0 }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                }

                if !desc.description.isEmpty {
                    Text(desc.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Path panel configuration

    /// Per-action, per-key panel settings.  Returns nil for non-path fields.
    private func pathPanelConfig(for key: String) -> PathPanelConfig? {
        switch actionTypeID {
        case "com.controlplane.action.open":
            if key == "path" {
                return PathPanelConfig(
                    title: "Choose a file or application to open",
                    canChooseFiles: true,
                    canChooseDirectories: true,
                    allowedTypes: nil          // any file or .app bundle
                )
            }

        case "com.controlplane.action.openandhide":
            if key == "path" {
                return PathPanelConfig(
                    title: "Choose an application to open and hide",
                    canChooseFiles: false,
                    canChooseDirectories: true,
                    allowedTypes: [.applicationBundle]
                )
            }

        case "com.controlplane.action.shellscript":
            if key == "scriptPath" {
                return PathPanelConfig(
                    title: "Choose a shell script",
                    canChooseFiles: true,
                    canChooseDirectories: false,
                    allowedTypes: [.shellScript, .unixExecutable, .plainText]
                )
            }

        case "com.controlplane.action.desktopbackground":
            if key == "imagePath" {
                return PathPanelConfig(
                    title: "Choose a background image",
                    canChooseFiles: true,
                    canChooseDirectories: false,
                    allowedTypes: [.image]
                )
            }

        case "com.controlplane.action.unmountvolume":
            if key == "volumePath" {
                return PathPanelConfig(
                    title: "Choose a volume to unmount",
                    canChooseFiles: false,
                    canChooseDirectories: true,
                    allowedTypes: nil,
                    directoryURL: URL(fileURLWithPath: "/Volumes")
                )
            }

        default:
            break
        }
        return nil
    }

    private func browse(config: PathPanelConfig, key: String) {
        let panel = NSOpenPanel()
        panel.title = config.title
        panel.canChooseFiles = config.canChooseFiles
        panel.canChooseDirectories = config.canChooseDirectories
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        if let types = config.allowedTypes {
            panel.allowedContentTypes = types
        }
        if let dir = config.directoryURL {
            panel.directoryURL = dir
        }
        if panel.runModal() == .OK, let url = panel.url {
            configValues[key] = url.path
        }
    }

    // MARK: - Save

    private func save() {
        let cleanedConfig = configValues.filter {
            !$0.value.trimmingCharacters(in: .whitespaces).isEmpty
        }
        Task {
            await store.createProfileAction(
                profileID: profile.id,
                actionPluginID: actionTypeID,
                trigger: trigger,
                config: cleanedConfig
            )
            onSave()
            dismiss()
        }
    }
}

// MARK: - Path panel configuration struct

private struct PathPanelConfig {
    let title: String
    let canChooseFiles: Bool
    let canChooseDirectories: Bool
    let allowedTypes: [UTType]?
    var directoryURL: URL? = nil
}
