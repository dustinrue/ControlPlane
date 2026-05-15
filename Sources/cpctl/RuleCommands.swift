import ArgumentParser
import Foundation
import ControlPlaneSDK

// MARK: - rules group

struct RulesCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "rules",
        abstract: "Create, read, update, and delete rules.",
        subcommands: [
            RulesList.self,
            RulesAdd.self,
            RulesDelete.self,
            RulesEnable.self,
            RulesDisable.self,
        ]
    )
}

// MARK: - rules list

struct RulesList: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all rules, or rules for a specific profile."
    )

    @Option(name: .long, help: "Filter by profile name or UUID.")
    var profile: String?

    @Flag(name: .long, help: "Output raw JSON.")
    var json: Bool = false

    mutating func run() async throws {
        let client = XPCClient()

        // Fetch rules and match status concurrently.
        async let rulesTask: [Rule] = {
            if let profile {
                let p = try await client.resolveProfile(profile)
                return try await client.listRules(forProfile: p.id)
            } else {
                return try await client.listRules()
            }
        }()
        async let matchTask = client.ruleMatchStatus()

        let (rules, matchStatus) = try await (rulesTask, matchTask)

        if json {
            print(try prettyJSONRules(rules))
            return
        }

        if rules.isEmpty {
            print("No rules.")
            return
        }

        print("\(col("ID", 36))  \(col("NAME", 20))  \(col("SENSOR", 28))  \(col("KEY", 16))  \(col("OP", 10))  \(col("COMPARAND", 20))  WT    EN   MATCH")
        print(String(repeating: "-", count: 160))
        for r in rules {
            let en    = r.enabled ? "yes" : "no"
            let wt    = String(format: "%.1f", r.weight)
            let match: String
            if !r.enabled {
                match = "-"
            } else if let m = matchStatus[r.id.uuidString] {
                match = m ? "✓" : "✗"
            } else {
                match = "?"   // not yet evaluated (backend just started)
            }
            print("\(col(r.id.uuidString, 36))  \(col(r.name, 20))  \(col(r.sensorID, 28))  \(col(r.readingKey, 16))  \(col(r.operatorID, 10))  \(col(r.comparand.description, 20))  \(col(wt, 5)) \(col(en, 4)) \(match)")
        }
    }
}

// MARK: - rules add

struct RulesAdd: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Create a new rule and attach it to a profile."
    )

    @Option(name: .long, help: "Profile name or UUID this rule contributes to.")
    var profile: String

    @Option(name: .long, help: "Sensor identifier, e.g. com.controlplane.wifi.")
    var sensor: String

    @Option(name: .long, help: "Reading key within the sensor, e.g. ssid.")
    var key: String

    @Option(name: .long, help: "Operator: equals, notEquals, greaterThan, lessThan, contains, etc.")
    var op: String

    @Option(name: .long, help: "Value to compare against.")
    var value: String

    @Option(name: .long, help: "Rule display name (defaults to '<key> <op> <value>').")
    var name: String?

    @Option(name: .long, help: "Confidence weight added when this rule matches (default 1.0).")
    var weight: Double = 1.0

    @Option(name: .long, help: "Evaluator plugin ID (default: com.controlplane.evaluator.basic).")
    var evaluator: String = "com.controlplane.evaluator.basic"

    @Flag(name: .long, help: "Output raw JSON.")
    var json: Bool = false

    mutating func run() async throws {
        let profileID = try await XPCClient().resolveProfile(profile).id
        let comparand = parseValue(value)
        let ruleName = name ?? "\(key) \(op) \(value)"

        let rule = try await XPCClient().createRule(
            name: ruleName,
            profileID: profileID,
            sensorID: sensor,
            readingKey: key,
            operatorID: op,
            comparand: comparand,
            evaluatorID: evaluator,
            weight: weight
        )

        if json {
            print(try prettyJSONRules([rule]))
        } else {
            print("Created rule \(rule.id.uuidString)")
            print(rule.formatted())
        }
    }
}

// MARK: - rules delete

struct RulesDelete: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete a rule."
    )

    @Argument(help: "Rule UUID to delete.")
    var id: String

    @Flag(name: .shortAndLong, help: "Skip confirmation prompt.")
    var force: Bool = false

    mutating func run() async throws {
        let uuid = try requireUUID(id)
        if !force {
            print("Delete rule \(id)? [y/N] ", terminator: "")
            let answer = readLine()?.lowercased() ?? ""
            guard answer == "y" || answer == "yes" else {
                print("Aborted.")
                return
            }
        }
        try await XPCClient().deleteRule(id: uuid)
        print("Deleted \(id)")
    }
}

// MARK: - rules enable / disable

struct RulesEnable: AsyncParsableCommand {
    static var configuration = CommandConfiguration(commandName: "enable", abstract: "Enable a rule.")

    @Argument(help: "Rule UUID.")
    var id: String

    mutating func run() async throws {
        let uuid = try requireUUID(id)
        let client = XPCClient()
        let r = try await client.getRule(id: uuid)
        _ = try await client.updateRule(
            id: uuid, name: r.name, sensorID: r.sensorID, readingKey: r.readingKey,
            operatorID: r.operatorID, comparand: r.comparand,
            evaluatorID: r.evaluatorID, weight: r.weight, enabled: true
        )
        print("Rule \(id) enabled.")
    }
}

struct RulesDisable: AsyncParsableCommand {
    static var configuration = CommandConfiguration(commandName: "disable", abstract: "Disable a rule.")

    @Argument(help: "Rule UUID.")
    var id: String

    mutating func run() async throws {
        let uuid = try requireUUID(id)
        let client = XPCClient()
        let r = try await client.getRule(id: uuid)
        _ = try await client.updateRule(
            id: uuid, name: r.name, sensorID: r.sensorID, readingKey: r.readingKey,
            operatorID: r.operatorID, comparand: r.comparand,
            evaluatorID: r.evaluatorID, weight: r.weight, enabled: false
        )
        print("Rule \(id) disabled.")
    }
}

// MARK: - evaluators group

struct EvaluatorsCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "evaluators",
        abstract: "List loaded evaluator plugins and their supported operators.",
        subcommands: [EvaluatorsList.self]
    )
}

struct EvaluatorsList: AsyncParsableCommand {
    static var configuration = CommandConfiguration(commandName: "list", abstract: "List evaluators.")

    @Flag(name: .long, help: "Output raw JSON.")
    var json: Bool = false

    mutating func run() async throws {
        let evals = try await XPCClient().listEvaluators()

        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(data: try encoder.encode(evals), encoding: .utf8)!)
            return
        }

        if evals.isEmpty { print("No evaluators loaded."); return }

        for e in evals {
            print("\(e.displayName) (\(e.id))  v\(e.version)")
            print("  Operators:")
            for op in e.operators {
                let types = op.applicableTypes.joined(separator: ", ")
                print("    \(col(op.id, 24))  \(col(op.label, 6))  [\(types)]")
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

/// Parses a CLI value string as bool → number → string.
func parseValue(_ string: String) -> ObservationValue {
    if string.lowercased() == "true"  { return .boolean(true) }
    if string.lowercased() == "false" { return .boolean(false) }
    if let n = Double(string)         { return .number(n) }
    return .string(string)
}

private func prettyJSONRules<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return String(data: try encoder.encode(value), encoding: .utf8)!
}

private extension Rule {
    func formatted() -> String {
        let df = ISO8601DateFormatter()
        return """
        ID:        \(id.uuidString)
        Name:      \(name)
        Profile:   \(profileID.uuidString)
        Sensor:    \(sensorID)
        Key:       \(readingKey)
        Operator:  \(operatorID)
        Comparand: \(comparand)
        Evaluator: \(evaluatorID)
        Weight:    \(weight)
        Enabled:   \(enabled ? "yes" : "no")
        Created:   \(df.string(from: createdAt))
        """
    }
}
