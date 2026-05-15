import ArgumentParser
import Foundation
import ControlPlaneSDK

// MARK: - actions group

struct ActionsCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "actions",
        abstract: "Manage actions attached to profiles.",
        subcommands: [
            ActionsList.self,
            ActionsAdd.self,
            ActionsDelete.self,
            ActionsEnable.self,
            ActionsDisable.self,
            ActionsRun.self,
            ActionTypesList.self,
        ]
    )
}

// MARK: - actions list

struct ActionsList: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List actions attached to a profile."
    )

    @Option(name: .long, help: "Profile name or UUID.")
    var profile: String

    @Flag(name: .long, help: "Output raw JSON.")
    var json: Bool = false

    mutating func run() async throws {
        let profileID = try await XPCClient().resolveProfile(profile).id
        let actions = try await XPCClient().listProfileActions(forProfile: profileID)

        if json { print(try prettyJSON(actions)); return }

        if actions.isEmpty { print("No actions attached to this profile."); return }

        print("\(col("PLUGIN", 34))  \(col("TRIGGER", 12))  \(col("EN", 3))  \(col("LAST TRIGGERED", 20))  \(col("CONFIG", 24))  ID")
        print(String(repeating: "-", count: 140))
        for a in actions {
            let cfg       = a.config.isEmpty ? "-" : a.config.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
            let triggered = a.lastTriggeredAt.map { relativeTime($0) } ?? "-"
            print("\(col(a.actionPluginID, 34))  \(col(a.trigger.rawValue, 12))  \(col(a.enabled ? "yes" : "no", 3))  \(col(triggered, 20))  \(col(cfg, 24))  \(a.id.uuidString)")
        }
    }
}

// MARK: - actions add

struct ActionsAdd: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Attach an action to a profile."
    )

    @Option(name: .long, help: "Profile name or UUID.")
    var profile: String

    @Option(name: .long, help: "Action plugin ID (see: cpctl actions types).")
    var type: String

    @Option(name: .long, help: "When to fire: onActivate or onDeactivate.")
    var trigger: String = "onActivate"

    @Option(name: .long, parsing: .upToNextOption, help: "Config key=value pairs (e.g. --config title=Hello body=World).")
    var config: [String] = []

    @Flag(name: .long, help: "Output raw JSON.")
    var json: Bool = false

    mutating func run() async throws {
        let profileID = try await XPCClient().resolveProfile(profile).id
        guard let trig = ActionTrigger(rawValue: trigger) else {
            throw ValidationError("Invalid trigger '\(trigger)'. Use: onActivate, onDeactivate")
        }
        let configDict = try parseConfig(config)

        let action = try await XPCClient().createProfileAction(
            profileID: profileID,
            actionPluginID: type,
            trigger: trig,
            config: configDict
        )

        if json { print(try prettyJSON(action)) } else {
            print("Created action \(action.id.uuidString)")
            print(action.formatted())
        }
    }
}

// MARK: - actions delete

struct ActionsDelete: AsyncParsableCommand {
    static var configuration = CommandConfiguration(commandName: "delete", abstract: "Remove an action.")

    @Argument(help: "Action UUID.")
    var id: String

    @Flag(name: .shortAndLong)
    var force: Bool = false

    mutating func run() async throws {
        let uuid = try requireUUID(id)
        if !force {
            print("Delete action \(id)? [y/N] ", terminator: "")
            guard (readLine()?.lowercased() ?? "") == "y" else { print("Aborted."); return }
        }
        try await XPCClient().deleteProfileAction(id: uuid)
        print("Deleted \(id)")
    }
}

// MARK: - actions enable / disable

struct ActionsEnable: AsyncParsableCommand {
    static var configuration = CommandConfiguration(commandName: "enable", abstract: "Enable an action.")
    @Argument var id: String
    mutating func run() async throws {
        let uuid = try requireUUID(id)
        let client = XPCClient()
        let a = try await client.getProfileAction(id: uuid)
        _ = try await client.updateProfileAction(id: uuid, actionPluginID: a.actionPluginID, trigger: a.trigger, config: a.config, enabled: true)
        print("Action \(id) enabled.")
    }
}

struct ActionsDisable: AsyncParsableCommand {
    static var configuration = CommandConfiguration(commandName: "disable", abstract: "Disable an action.")
    @Argument var id: String
    mutating func run() async throws {
        let uuid = try requireUUID(id)
        let client = XPCClient()
        let a = try await client.getProfileAction(id: uuid)
        _ = try await client.updateProfileAction(id: uuid, actionPluginID: a.actionPluginID, trigger: a.trigger, config: a.config, enabled: false)
        print("Action \(id) disabled.")
    }
}

// MARK: - actions run

struct ActionsRun: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Execute a stored action immediately, regardless of whether its profile is active.",
        discussion: "Useful for testing actions without needing to activate their profile."
    )

    @Argument(help: "Action UUID (from `cpctl actions list --profile <name>`).")
    var id: String

    @Option(
        name: .long,
        help: "Trigger to use: onActivate or onDeactivate. Defaults to the action's stored trigger."
    )
    var trigger: String?

    mutating func run() async throws {
        let uuid = try requireUUID(id)

        let parsedTrigger: ActionTrigger?
        if let raw = trigger {
            guard let t = ActionTrigger(rawValue: raw) else {
                throw ValidationError("Invalid trigger '\(raw)'. Use: onActivate, onDeactivate")
            }
            parsedTrigger = t
        } else {
            parsedTrigger = nil
        }

        try await XPCClient().runProfileAction(id: uuid, trigger: parsedTrigger)

        let triggerNote = trigger.map { " (trigger: \($0))" } ?? ""
        print("Action \(id) executed successfully\(triggerNote).")
    }
}

// MARK: - actions types

struct ActionTypesList: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "types",
        abstract: "List available action plugins and their configuration keys."
    )

    @Flag(name: .long, help: "Output raw JSON.")
    var json: Bool = false

    mutating func run() async throws {
        let types = try await XPCClient().listActionTypes()

        if json { print(try prettyJSON(types)); return }
        if types.isEmpty { print("No action plugins loaded."); return }

        for t in types {
            print("\(t.displayName)  (\(t.id))  v\(t.version)")
            if t.configDescriptors.isEmpty {
                print("  No configuration keys.")
            } else {
                print("  Config keys:")
                for d in t.configDescriptors {
                    let req = d.required ? " [required]" : ""
                    let def = d.defaultValue.map { "  default: \($0)" } ?? ""
                    print("    \(col(d.key, 16))  \(d.description)\(req)\(def)")
                }
            }
            print()
        }
    }
}

// MARK: - Helpers

private func requireUUID(_ string: String) throws -> UUID {
    guard let uuid = UUID(uuidString: string) else {
        throw ValidationError("'\(string)' is not a valid UUID.")
    }
    return uuid
}

private func parseConfig(_ pairs: [String]) throws -> [String: String] {
    var dict: [String: String] = [:]
    for pair in pairs {
        let parts = pair.split(separator: "=", maxSplits: 1)
        guard parts.count == 2 else {
            throw ValidationError("Config must be key=value, got: \(pair)")
        }
        dict[String(parts[0])] = String(parts[1])
    }
    return dict
}

private func prettyJSON<T: Encodable>(_ value: T) throws -> String {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    e.outputFormatting = [.prettyPrinted, .sortedKeys]
    return String(data: try e.encode(value), encoding: .utf8)!
}

private extension ProfileAction {
    func formatted() -> String {
        let cfg = config.isEmpty ? "-" : config.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
        return """
        ID:      \(id.uuidString)
        Profile: \(profileID.uuidString)
        Plugin:  \(actionPluginID)
        Trigger: \(trigger.rawValue)
        Config:  \(cfg)
        Enabled: \(enabled ? "yes" : "no")
        """
    }
}
