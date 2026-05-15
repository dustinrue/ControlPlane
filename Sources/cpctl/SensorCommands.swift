import ArgumentParser
import Foundation
import ControlPlaneSDK

struct SensorsCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "sensors",
        abstract: "Inspect loaded sensors and their current readings.",
        subcommands: [SensorsList.self, SensorsReadings.self, SensorsOptions.self, SensorsSet.self]
    )
}

// MARK: - sensors options

struct SensorsOptions: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "options",
        abstract: "Show configurable options for a sensor."
    )

    @Argument(help: "Sensor identifier.")
    var id: String

    @Flag(name: .long, help: "Output raw JSON.")
    var json: Bool = false

    mutating func run() async throws {
        let opts = try await XPCClient().getSensorOptions(id: id)

        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(data: try encoder.encode(opts), encoding: .utf8)!)
            return
        }

        if opts.isEmpty {
            print("No configurable options for \(id).")
            return
        }

        print("\(col("KEY", 26))  \(col("VALUE", 10))  DESCRIPTION")
        print(String(repeating: "-", count: 80))
        for opt in opts {
            print("\(col(opt.key, 26))  \(col(opt.value.description, 10))  \(opt.description)")
        }
    }
}

// MARK: - sensors set

struct SensorsSet: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Set a configuration option on a sensor."
    )

    @Argument(help: "Sensor identifier.")
    var id: String

    @Argument(help: "Option key.")
    var key: String

    @Argument(help: "Value (true/false for booleans, number, or string).")
    var value: String

    mutating func run() async throws {
        let optionValue = parseValue(value)
        try await XPCClient().setSensorOption(id: id, key: key, value: optionValue)
        print("Set \(key) = \(optionValue) on \(id)")
    }

    private func parseValue(_ s: String) -> SensorOptionValue {
        if s == "true"  { return .bool(true)  }
        if s == "false" { return .bool(false) }
        if let n = Double(s) { return .number(n) }
        return .string(s)
    }
}

// MARK: - sensors list

struct SensorsList: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all loaded sensors and their active state."
    )

    @Flag(name: .long, help: "Output raw JSON.")
    var json: Bool = false

    mutating func run() async throws {
        let snapshots = try await XPCClient().listSensorReadings()

        if json {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(data: try encoder.encode(snapshots), encoding: .utf8)!)
            return
        }

        if snapshots.isEmpty {
            print("No sensors loaded.")
            return
        }

        print("\(col("ID", 44))  \(col("NAME", 20))  ACTIVE")
        print(String(repeating: "-", count: 72))
        for s in snapshots {
            print("\(col(s.sensorID, 44))  \(col(s.displayName, 20))  \(s.isActive ? "yes" : "no")")
        }
    }
}

// MARK: - sensors readings

struct SensorsReadings: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "readings",
        abstract: "Show current readings from sensors."
    )

    @Option(name: .shortAndLong, help: "Sensor identifier to query. Omit for all sensors.")
    var sensor: String?

    @Flag(name: .long, help: "Output raw JSON.")
    var json: Bool = false

    mutating func run() async throws {
        let client = XPCClient()
        let snapshots: [SensorSnapshot]

        if let id = sensor {
            snapshots = [try await client.getSensorReadings(id: id)]
        } else {
            snapshots = try await client.listSensorReadings()
        }

        if json {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(data: try encoder.encode(snapshots), encoding: .utf8)!)
            return
        }

        if snapshots.isEmpty {
            print("No sensors loaded.")
            return
        }

        for snapshot in snapshots {
            let df = ISO8601DateFormatter()

            let status = snapshot.isActive ? "active" : "inactive"
            print("\(snapshot.displayName)  [\(snapshot.sensorID)]  \(status)  @ \(df.string(from: snapshot.capturedAt))")
            if snapshot.readings.isEmpty {
                print("  (no readings)")
            } else {
                for r in snapshot.readings {
                    printReading(r)
                }
            }
            print("")
        }
    }

    // Key column width + label column width + separators = value indent
    private static let valueIndent = 2 + 16 + 2 + 24 + 2

    private func printReading(_ r: SensorReading) {
        let prefix = "  \(col(r.key, 16))  \(col(r.label, 24))  "
        if case .strings(let values) = r.value {
            if values.isEmpty {
                print("\(prefix)(none)")
            } else {
                print("\(prefix)\(values[0])")
                let indent = String(repeating: " ", count: Self.valueIndent)
                for v in values.dropFirst() {
                    print("\(indent)\(v)")
                }
            }
        } else {
            print("\(prefix)\(r.value)")
        }
    }
}
