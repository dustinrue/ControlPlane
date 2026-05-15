import ArgumentParser
import Foundation
import ControlPlaneSDK

struct StatusCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show backend health and summary."
    )

    @Flag(name: .long, help: "Output raw JSON.")
    var json: Bool = false

    mutating func run() async throws {
        let status = try await XPCClient().getStatus()

        if json {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(data: try encoder.encode(status), encoding: .utf8)!)
            return
        }

        let uptime = uptimeString(since: status.startedAt)
        let c = status.pluginCounts

        print("""
        ControlPlane Backend
          PID:      \(status.pid)
          Version:  \(status.version)
          Uptime:   \(uptime)
          Profiles: \(status.profileCount)
          Plugins:  \(c.sensors) sensor\(c.sensors == 1 ? "" : "s"), \
        \(c.actions) action\(c.actions == 1 ? "" : "s"), \
        \(c.intelligence) intelligence engine\(c.intelligence == 1 ? "" : "s")
        """)
    }
}

private func uptimeString(since date: Date) -> String {
    var seconds = Int(Date().timeIntervalSince(date))
    let hours = seconds / 3600;   seconds %= 3600
    let minutes = seconds / 60;   seconds %= 60
    if hours > 0   { return "\(hours)h \(minutes)m \(seconds)s" }
    if minutes > 0 { return "\(minutes)m \(seconds)s" }
    return "\(seconds)s"
}
