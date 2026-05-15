import Foundation
import ControlPlaneSDK

/// Discovers and loads plugin bundles from the app bundle and user plugin directory.
///
/// Plugin bundles must:
///   1. Have a principal class (NSPrincipalClass in Info.plist) that subclasses NSObject
///      and conforms to ControlPlanePlugin.
///   2. Live in a Sensors/, Actions/, or Intelligence/ subdirectory.
///
/// First-party plugins ship inside the backend binary's bundle:
///   Contents/Plugins/Sensors/WiFiSensor.bundle, etc.
///
/// Third-party plugins are installed to:
///   ~/Library/Application Support/ControlPlane/Plugins/{Sensors,Actions,Intelligence}/
final class PluginLoader {
    private let registry: PluginRegistry
    private let sensors: SensorCoordinator
    private let categories = ["Sensors", "Actions", "Intelligence"]

    init(registry: PluginRegistry, sensors: SensorCoordinator) {
        self.registry = registry
        self.sensors = sensors
    }

    func discoverPlugins() {
        log("Plugin discovery starting")
        for (directory, source) in searchDirectories() {
            load(from: directory, source: source)
        }
        log("Plugin discovery complete")
    }

    // MARK: - Private

    private func searchDirectories() -> [(URL, PluginInfo.PluginSource)] {
        var dirs: [(URL, PluginInfo.PluginSource)] = []

        let bundlePlugins = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Plugins")
        for category in categories {
            dirs.append((bundlePlugins.appendingPathComponent(category), .bundled))
        }

        if let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        {
            let userPlugins = appSupport.appendingPathComponent("ControlPlane/Plugins")
            for category in categories {
                dirs.append((userPlugins.appendingPathComponent(category), .user))
            }
        }

        return dirs
    }

    private func load(from directory: URL, source: PluginInfo.PluginSource) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path) else {
            log("Plugin directory absent (skipping): \(directory.path)")
            return
        }

        let bundles: [URL]
        do {
            bundles = try fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            ).filter { $0.pathExtension == "bundle" }
        } catch {
            log("Failed to read plugin directory \(directory.path): \(error.localizedDescription)")
            return
        }

        if bundles.isEmpty {
            log("No plugins in \(directory.path)")
            return
        }

        for url in bundles {
            loadBundle(at: url, source: source)
        }
    }

    private func loadBundle(at url: URL, source: PluginInfo.PluginSource) {
        guard let bundle = Bundle(url: url) else {
            log("Could not create Bundle from \(url.lastPathComponent)")
            return
        }

        guard bundle.load() else {
            log("Failed to load bundle \(url.lastPathComponent)")
            return
        }

        guard let principalClass = bundle.principalClass else {
            log("No NSPrincipalClass declared in \(url.lastPathComponent)")
            return
        }

        guard let objectType = principalClass as? NSObject.Type else {
            log("Principal class in \(url.lastPathComponent) does not subclass NSObject")
            return
        }

        let instance = objectType.init()

        guard let plugin = instance as? ControlPlanePlugin else {
            log("Principal class in \(url.lastPathComponent) does not conform to ControlPlanePlugin")
            return
        }

        register(plugin, source: source)
    }

    private func register(_ plugin: ControlPlanePlugin, source: PluginInfo.PluginSource) {
        let rawCategory = plugin.pluginCategory

        let category: PluginInfo.PluginCategory
        switch rawCategory {
        case "sensor":
            guard let sensorPlugin = plugin as? (any SensorPlugin) else {
                log("Plugin \(plugin.pluginIdentifier) declares category 'sensor' but does not conform to SensorPlugin")
                return
            }
            guard type(of: sensorPlugin).isApplicable() else {
                log("Sensor \(plugin.pluginIdentifier) is not applicable on this system — skipping")
                return
            }
            Task { await self.sensors.add(sensorPlugin) }
            category = .sensor

        case "action":
            guard plugin is ActionPlugin else {
                log("Plugin \(plugin.pluginIdentifier) declares category 'action' but does not conform to ActionPlugin")
                return
            }
            category = .action

        case "intelligence":
            category = .intelligence

        default:
            log("Unknown plugin category '\(rawCategory)' in \(plugin.pluginIdentifier)")
            return
        }

        let info = PluginInfo(
            id: plugin.pluginIdentifier,
            displayName: plugin.pluginDisplayName,
            version: plugin.pluginVersion,
            category: category,
            source: source
        )

        Task { await registry.register(info) }

        log("Loaded \(rawCategory) plugin: \(plugin.pluginDisplayName) (\(plugin.pluginIdentifier)) v\(plugin.pluginVersion) [\(source.rawValue)]")
    }
}
