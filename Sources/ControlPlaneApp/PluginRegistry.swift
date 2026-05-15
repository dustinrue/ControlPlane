import Foundation
import ControlPlaneSDK

/// Stores metadata for every successfully loaded plugin.
/// Queried by the XPC status and plugin-list endpoints.
actor PluginRegistry {
    private var plugins: [PluginInfo] = []

    func register(_ info: PluginInfo) {
        plugins.append(info)
    }

    func list() -> [PluginInfo] {
        plugins.sorted { $0.id < $1.id }
    }

    func counts() -> BackendStatus.PluginCounts {
        BackendStatus.PluginCounts(
            sensors:      plugins.filter { $0.category == .sensor }.count,
            actions:      plugins.filter { $0.category == .action }.count,
            intelligence: plugins.filter { $0.category == .intelligence }.count
        )
    }
}
