import Foundation
import ControlPlaneSDK

/// Stores loaded action plugins and vends them by ID.
actor ActionRegistry {
    private var plugins: [String: any ActionPlugin] = [:]

    func register(_ plugin: any ActionPlugin) {
        plugins[plugin.pluginIdentifier] = plugin
        log("Action plugin registered: \(plugin.pluginIdentifier)", CPLogger.plugins)
    }

    func plugin(for id: String) -> (any ActionPlugin)? {
        plugins[id]
    }

    func list() -> [ActionTypeInfo] {
        plugins.values.map { p in
            ActionTypeInfo(
                id: p.pluginIdentifier,
                displayName: p.pluginDisplayName,
                version: p.pluginVersion,
                configDescriptors: p.configurationDescriptors()
            )
        }.sorted { $0.id < $1.id }
    }

    func count() -> Int { plugins.count }
}
