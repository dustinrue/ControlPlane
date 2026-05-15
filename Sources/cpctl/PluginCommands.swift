import ArgumentParser
import Foundation
import ControlPlaneSDK

struct PluginsCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "plugins",
        abstract: "Inspect loaded plugins.",
        subcommands: [PluginsList.self]
    )
}

struct PluginsList: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all loaded plugins."
    )

    @Option(name: .long, help: "Filter by category: sensor, action, intelligence.")
    var category: String?

    @Flag(name: .long, help: "Output raw JSON.")
    var json: Bool = false

    mutating func run() async throws {
        var plugins = try await XPCClient().listPlugins()

        if let category {
            guard let cat = PluginInfo.PluginCategory(rawValue: category) else {
                throw ValidationError("Unknown category '\(category)'. Use: sensor, action, intelligence.")
            }
            plugins = plugins.filter { $0.category == cat }
        }

        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(data: try encoder.encode(plugins), encoding: .utf8)!)
            return
        }

        if plugins.isEmpty {
            print(category.map { "No \($0) plugins loaded." } ?? "No plugins loaded.")
            return
        }

        print("\(col("CATEGORY", 14))  \(col("IDENTIFIER", 44))  \(col("NAME", 28))  \(col("VERSION", 8))  SOURCE")
        print(String(repeating: "-", count: 110))
        for p in plugins {
            print("\(col(p.category.rawValue, 14))  \(col(p.id, 44))  \(col(p.displayName, 28))  \(col(p.version, 8))  \(p.source.rawValue)")
        }
    }
}
