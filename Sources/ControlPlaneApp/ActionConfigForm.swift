import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers
import ControlPlaneSDK

/// Per-action configuration UI rendered inside the Create/Edit Action sheet.
/// Each known plugin ID gets its own purpose-built section; unknown plugins fall
/// back to generic text fields from the plugin's configDescriptors.
struct ActionConfigForm: View {

    let pluginID: String
    @Binding var config: [String: String]

    // Lazily-loaded external data
    @State private var networkLocations: [String] = []
    @State private var printerNames: [String] = []
    @State private var voices: [(id: String, name: String, locale: String)] = []
    @State private var shortcuts: [(id: String, name: String)] = []
    @State private var installedApps: [(path: String, name: String, bundleID: String)] = []
    @State private var mountedVolumes: [String] = []
    @State private var isLoadingExternal = false

    var body: some View {
        Group {
            switch pluginID {
            case "com.controlplane.action.shellscript":
                shellScriptConfig
            case "com.controlplane.action.open":
                openFileConfig
            case "com.controlplane.action.openandhide":
                openAndHideConfig
            case "com.controlplane.action.openurl":
                openURLConfig
            case "com.controlplane.action.quitapplication":
                quitAppConfig
            case "com.controlplane.action.speak":
                speakConfig
            case "com.controlplane.action.mountvolume":
                mountVolumeConfig
            case "com.controlplane.action.unmountvolume":
                unmountVolumeConfig
            case "com.controlplane.action.desktopbackground":
                desktopBackgroundConfig
            case "com.controlplane.action.togglewifi":
                onOffConfig(key: "state", label: "WiFi")
            case "com.controlplane.action.preventdisplaysleep":
                onOffConfig(key: "state", label: "Prevent Display Sleep")
            case "com.controlplane.action.preventsystemsleep":
                onOffConfig(key: "state", label: "Prevent System Sleep")
            case "com.controlplane.action.networklocation":
                networkLocationConfig
            case "com.controlplane.action.defaultprinter":
                defaultPrinterConfig
            case "com.controlplane.action.shortcut":
                shortcutConfig
            case "com.controlplane.action.timemachinedestination":
                timeMachineDestConfig
            case "com.controlplane.action.starttimemachine",
                 "com.controlplane.action.startscreensaver",
                 "com.controlplane.action.lockkeychain":
                // No configuration needed
                noConfigNeeded
            default:
                EmptyView()
            }
        }
        .onAppear { loadExternalData() }
        .onChange(of: pluginID) { _ in loadExternalData() }
    }

    // MARK: - No-config actions

    private var noConfigNeeded: some View {
        Section {
            Text("No configuration required for this action.")
                .foregroundStyle(.secondary)
        } header: {
            Text("Configuration")
        }
    }

    // MARK: - Shell Script

    private var shellScriptConfig: some View {
        Section {
            pathField(
                key: "scriptPath",
                label: "Script",
                placeholder: "/usr/local/bin/my-script.sh",
                panelConfig: PathPanelConfig(
                    title: "Choose a shell script",
                    canChooseFiles: true,
                    canChooseDirectories: false,
                    allowedTypes: [.shellScript, .unixExecutable, .plainText]
                )
            )

            LabeledContent("Arguments") {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Optional", text: configBinding("arguments"))
                        .textFieldStyle(.roundedBorder)
                    Text("Space-separated arguments passed to the script.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } header: { Text("Configuration") }
    }

    // MARK: - Open File or Application

    private var openFileConfig: some View {
        Section {
            pathField(
                key: "path",
                label: "File or App",
                placeholder: "/Applications/Safari.app",
                panelConfig: PathPanelConfig(
                    title: "Choose a file or application to open",
                    canChooseFiles: true,
                    canChooseDirectories: true,
                    allowedTypes: nil
                )
            )
        } header: { Text("Configuration") }
    }

    // MARK: - Open and Hide Application

    private var openAndHideConfig: some View {
        Section {
            pathField(
                key: "path",
                label: "Application",
                placeholder: "/Applications/Mail.app",
                panelConfig: PathPanelConfig(
                    title: "Choose an application to open and hide",
                    canChooseFiles: false,
                    canChooseDirectories: true,
                    allowedTypes: [.applicationBundle]
                )
            )
            Text("The application launches in the background — its windows will not come to the front.")
                .font(.caption).foregroundStyle(.secondary)
        } header: { Text("Configuration") }
    }

    // MARK: - Open URL

    private var openURLConfig: some View {
        Section {
            LabeledContent("URL") {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("https://example.com", text: configBinding("url"))
                        .textFieldStyle(.roundedBorder)
                    Text("Any URL scheme supported by macOS, e.g. https://, ftp://, or a custom app URL.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } header: { Text("Configuration") }
    }

    // MARK: - Quit Application

    private var quitAppConfig: some View {
        Section {
            if installedApps.isEmpty {
                LabeledContent("Application") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("com.apple.Safari", text: configBinding("bundleIdentifier"))
                            .textFieldStyle(.roundedBorder)
                        if isLoadingExternal {
                            ProgressView().controlSize(.small)
                        }
                    }
                }
            } else {
                LabeledContent("Application") {
                    Picker("", selection: configBinding("bundleIdentifier")) {
                        Text("Choose…").tag("")
                        ForEach(installedApps, id: \.bundleID) { app in
                            Text(app.name).tag(app.bundleID)
                        }
                    }
                    .labelsHidden()
                }
            }

            LabeledContent("Quit Mode") {
                Picker("", selection: configBinding("force")) {
                    Text("Graceful (ask to save)").tag("false")
                    Text("Force quit (no save prompt)").tag("true")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onAppear {
                    if config["force"] == nil { config["force"] = "false" }
                }
            }
        } header: { Text("Configuration") }
    }

    // MARK: - Speak Text

    private var speakConfig: some View {
        Section {
            LabeledContent("Text to Speak") {
                TextField("Welcome home.", text: configBinding("text"))
                    .textFieldStyle(.roundedBorder)
            }

            LabeledContent("Voice") {
                if voices.isEmpty {
                    HStack {
                        TextField("System default", text: configBinding("voice"))
                            .textFieldStyle(.roundedBorder)
                        if isLoadingExternal { ProgressView().controlSize(.small) }
                    }
                } else {
                    Picker("", selection: configBinding("voice")) {
                        Text("System default").tag("")
                        ForEach(groupedVoices, id: \.locale) { group in
                            Section(group.locale) {
                                ForEach(group.voices, id: \.id) { voice in
                                    Text(voice.name).tag(voice.id)
                                }
                            }
                        }
                    }
                    .labelsHidden()
                }
            }
        } header: { Text("Configuration") }
    }

    private var groupedVoices: [(locale: String, voices: [(id: String, name: String)])] {
        let grouped = Dictionary(grouping: voices, by: \.locale)
        return grouped
            .map { (locale: $0.key, voices: $0.value.map { (id: $0.id, name: $0.name) }) }
            .sorted { $0.locale < $1.locale }
    }

    // MARK: - Mount Volume

    private var mountVolumeConfig: some View {
        Section {
            LabeledContent("Server URL") {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("smb://server/share", text: configBinding("serverURL"))
                        .textFieldStyle(.roundedBorder)
                    Text("Supports smb://, afp://, and nfs:// schemes.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } header: { Text("Configuration") }
    }

    // MARK: - Unmount Volume

    private var unmountVolumeConfig: some View {
        Section {
            if mountedVolumes.isEmpty {
                pathField(
                    key: "volumePath",
                    label: "Volume",
                    placeholder: "/Volumes/MyDrive",
                    panelConfig: PathPanelConfig(
                        title: "Choose a volume to unmount",
                        canChooseFiles: false,
                        canChooseDirectories: true,
                        allowedTypes: nil,
                        directoryURL: URL(fileURLWithPath: "/Volumes")
                    )
                )
            } else {
                LabeledContent("Volume") {
                    Picker("", selection: configBinding("volumePath")) {
                        Text("Choose…").tag("")
                        ForEach(mountedVolumes, id: \.self) { vol in
                            Text(vol.hasPrefix("/Volumes/") ? String(vol.dropFirst(9)) : vol)
                                .tag(vol)
                        }
                    }
                    .labelsHidden()
                }
            }
        } header: { Text("Configuration") }
    }

    // MARK: - Desktop Background

    private var desktopBackgroundConfig: some View {
        Section {
            pathField(
                key: "imagePath",
                label: "Image",
                placeholder: "/path/to/wallpaper.jpg",
                panelConfig: PathPanelConfig(
                    title: "Choose a background image",
                    canChooseFiles: true,
                    canChooseDirectories: false,
                    allowedTypes: [.image]
                )
            )

            LabeledContent("Apply To") {
                Picker("", selection: configBinding("screen")) {
                    Text("All Displays").tag("all")
                    Text("Main Display Only").tag("main")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onAppear {
                    if config["screen"] == nil { config["screen"] = "all" }
                }
            }
        } header: { Text("Configuration") }
    }

    // MARK: - On / Off toggle (WiFi, sleep prevention)

    private func onOffConfig(key: String, label: String) -> some View {
        Section {
            LabeledContent(label) {
                Picker("", selection: configBinding(key)) {
                    Text("Enable").tag("on")
                    Text("Disable").tag("off")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onAppear {
                    if config[key] == nil { config[key] = "on" }
                }
            }
        } header: { Text("Configuration") }
    }

    // MARK: - Switch Network Location

    private var networkLocationConfig: some View {
        Section {
            LabeledContent("Location") {
                if networkLocations.isEmpty {
                    HStack {
                        TextField("Automatic", text: configBinding("locationName"))
                            .textFieldStyle(.roundedBorder)
                        if isLoadingExternal { ProgressView().controlSize(.small) }
                    }
                } else {
                    Picker("", selection: configBinding("locationName")) {
                        Text("Choose…").tag("")
                        ForEach(networkLocations, id: \.self) { loc in
                            Text(loc).tag(loc)
                        }
                    }
                    .labelsHidden()
                }
            }
        } header: { Text("Configuration") }
    }

    // MARK: - Set Default Printer

    private var defaultPrinterConfig: some View {
        Section {
            LabeledContent("Printer") {
                if printerNames.isEmpty {
                    HStack {
                        TextField("Printer name", text: configBinding("printerName"))
                            .textFieldStyle(.roundedBorder)
                        if isLoadingExternal { ProgressView().controlSize(.small) }
                    }
                } else {
                    Picker("", selection: configBinding("printerName")) {
                        Text("Choose…").tag("")
                        ForEach(printerNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .labelsHidden()
                }
            }
        } header: { Text("Configuration") }
    }

    // MARK: - Run Shortcut

    private var shortcutConfig: some View {
        Section {
            LabeledContent("Shortcut") {
                if shortcuts.isEmpty {
                    HStack {
                        TextField("Shortcut UUID", text: configBinding("shortcutID"))
                            .textFieldStyle(.roundedBorder)
                        if isLoadingExternal { ProgressView().controlSize(.small) }
                    }
                } else {
                    Picker("", selection: configBinding("shortcutID")) {
                        Text("Choose…").tag("")
                        ForEach(shortcuts, id: \.id) { sc in
                            Text(sc.name).tag(sc.id)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: config["shortcutID"]) { newID in
                        // Auto-fill the display name when the user picks a shortcut.
                        if let sc = shortcuts.first(where: { $0.id == newID }) {
                            config["shortcutName"] = sc.name
                        }
                    }
                }
            }
            if let name = config["shortcutName"], !name.isEmpty {
                LabeledContent("Name") {
                    Text(name).foregroundStyle(.secondary)
                }
            }
        } header: { Text("Configuration") }
    }

    // MARK: - Time Machine Destination

    private var timeMachineDestConfig: some View {
        Section {
            pathField(
                key: "destination",
                label: "Destination",
                placeholder: "/Volumes/Backup",
                panelConfig: PathPanelConfig(
                    title: "Choose a Time Machine destination",
                    canChooseFiles: false,
                    canChooseDirectories: true,
                    allowedTypes: nil
                )
            )
        } header: { Text("Configuration") }
    }

    // MARK: - Shared helpers

    /// A text field + Browse button for a file-system path.
    private func pathField(
        key: String,
        label: String,
        placeholder: String,
        panelConfig: PathPanelConfig
    ) -> some View {
        LabeledContent(label) {
            HStack(spacing: 6) {
                TextField(placeholder, text: configBinding(key))
                    .textFieldStyle(.roundedBorder)
                Button("Browse…") { browseForPath(key: key, config: panelConfig) }
                    .controlSize(.small)
            }
        }
    }

    private func configBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { config[key] ?? "" },
            set: { config[key] = $0.isEmpty ? nil : $0 }
        )
    }

    private func browseForPath(key: String, config panelConfig: PathPanelConfig) {
        let panel = NSOpenPanel()
        panel.title = panelConfig.title
        panel.canChooseFiles = panelConfig.canChooseFiles
        panel.canChooseDirectories = panelConfig.canChooseDirectories
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        if let types = panelConfig.allowedTypes { panel.allowedContentTypes = types }
        if let dir = panelConfig.directoryURL { panel.directoryURL = dir }
        if panel.runModal() == .OK, let url = panel.url {
            config[key] = url.path
        }
    }

    // MARK: - External data loading

    private func loadExternalData() {
        switch pluginID {
        case "com.controlplane.action.networklocation":
            loadNetworkLocations()
        case "com.controlplane.action.defaultprinter":
            loadPrinters()
        case "com.controlplane.action.speak":
            loadVoices()
        case "com.controlplane.action.shortcut":
            loadShortcuts()
        case "com.controlplane.action.quitapplication":
            loadInstalledApps()
        case "com.controlplane.action.unmountvolume":
            loadMountedVolumes()
        default:
            break
        }
    }

    private func loadNetworkLocations() {
        guard networkLocations.isEmpty else { return }
        isLoadingExternal = true
        Task.detached(priority: .userInitiated) {
            let pipe = Pipe()
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
            proc.arguments = ["-listlocations"]
            proc.standardOutput = pipe
            proc.standardError = Pipe()
            try? proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let locations = (String(data: data, encoding: .utf8) ?? "")
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            await MainActor.run {
                self.networkLocations = locations
                self.isLoadingExternal = false
            }
        }
    }

    private func loadPrinters() {
        guard printerNames.isEmpty else { return }
        let names = NSPrinter.printerNames
        printerNames = names.sorted()
    }

    private func loadVoices() {
        guard voices.isEmpty else { return }
        let allVoices = NSSpeechSynthesizer.availableVoices
        voices = allVoices.compactMap { voiceID in
            let attrs = NSSpeechSynthesizer.attributes(forVoice: voiceID)
            guard let name = attrs[NSSpeechSynthesizer.VoiceAttributeKey.name] as? String else { return nil }
            let locale = attrs[NSSpeechSynthesizer.VoiceAttributeKey.localeIdentifier] as? String ?? "Other"
            // Convert locale like "en_US" to "English (US)"
            let displayLocale = Locale(identifier: locale)
                .localizedString(forIdentifier: locale) ?? locale
            return (id: voiceID.rawValue, name: name, locale: displayLocale)
        }
        .sorted { $0.locale < $1.locale }
    }

    private func loadShortcuts() {
        guard shortcuts.isEmpty else { return }
        isLoadingExternal = true
        Task.detached(priority: .userInitiated) {
            let pipe = Pipe()
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            proc.arguments = ["list", "--show-identifiers"]
            proc.standardOutput = pipe
            proc.standardError = Pipe()
            try? proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            // Each line: "Shortcut Name (UUID)"
            let parsed: [(id: String, name: String)] = output
                .components(separatedBy: .newlines)
                .compactMap { line in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard trimmed.hasSuffix(")"),
                          let openParen = trimmed.lastIndex(of: "(") else { return nil }
                    let name = String(trimmed[trimmed.startIndex..<openParen]).trimmingCharacters(in: .whitespaces)
                    let uuid = String(trimmed[trimmed.index(after: openParen)..<trimmed.index(before: trimmed.endIndex)])
                    guard !name.isEmpty, !uuid.isEmpty else { return nil }
                    return (id: uuid, name: name)
                }
                .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            await MainActor.run {
                self.shortcuts = parsed
                self.isLoadingExternal = false
            }
        }
    }

    private func loadInstalledApps() {
        guard installedApps.isEmpty else { return }
        isLoadingExternal = true
        Task.detached(priority: .userInitiated) {
            let searchDirs = [
                "/Applications",
                (NSHomeDirectory() as NSString).appendingPathComponent("Applications"),
                "/System/Applications"
            ]
            var apps: [(path: String, name: String, bundleID: String)] = []
            let fm = FileManager.default
            for dir in searchDirs {
                guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { continue }
                for entry in entries where entry.hasSuffix(".app") {
                    let fullPath = (dir as NSString).appendingPathComponent(entry)
                    guard let bundle = Bundle(path: fullPath),
                          let bundleID = bundle.bundleIdentifier else { continue }
                    let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                        ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                        ?? (entry as NSString).deletingPathExtension
                    apps.append((path: fullPath, name: name, bundleID: bundleID))
                }
            }
            let sorted = apps.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            await MainActor.run {
                self.installedApps = sorted
                self.isLoadingExternal = false
            }
        }
    }

    private func loadMountedVolumes() {
        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeNameKey],
            options: .skipHiddenVolumes
        ) ?? []
        mountedVolumes = urls
            .map { $0.path }
            .filter { $0 != "/" }
            .sorted()
    }
}

// MARK: - PathPanelConfig

struct PathPanelConfig {
    let title: String
    let canChooseFiles: Bool
    let canChooseDirectories: Bool
    let allowedTypes: [UTType]?
    var directoryURL: URL? = nil
}

