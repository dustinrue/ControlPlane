import ArgumentParser
import Foundation

/// Top-level `shortcuts` subcommand group.
struct ShortcutsCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "shortcuts",
        abstract: "Work with macOS Shortcuts.",
        subcommands: [ListShortcutsCommand.self]
    )
}

/// `cpctl shortcuts list`
///
/// Enumerates all macOS Shortcuts available to the current user by running:
///
///     /usr/bin/shortcuts list --show-identifiers
///
/// Output looks like:
///
///     NAME                            UUID
///     Morning Routine                 A1B2C3D4-1234-...
///     Send Daily Report               B2C3D4E5-5678-...
///
/// No backend connection is needed — the `shortcuts` binary is part of macOS.
struct ListShortcutsCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all available macOS Shortcuts with their UUIDs."
    )

    @Flag(name: .shortAndLong, help: "Output raw lines (name<TAB>UUID) suitable for scripting.")
    var raw = false

    func run() async throws {
        let shortcutsPath = "/usr/bin/shortcuts"
        guard FileManager.default.fileExists(atPath: shortcutsPath) else {
            throw CleanExit.message("Error: /usr/bin/shortcuts not found. Requires macOS 12+.")
        }

        let output = try await runProcess(
            executable: shortcutsPath,
            arguments: ["list", "--show-identifiers"]
        )

        let entries = parseShortcutsList(output)

        if entries.isEmpty {
            print("No shortcuts found.")
            return
        }

        if raw {
            for (name, uuid) in entries {
                print("\(name)\t\(uuid)")
            }
        } else {
            printTable(entries)
        }
    }

    // MARK: - Parsing

    /// Parses lines produced by `shortcuts list --show-identifiers`.
    ///
    /// Each line is formatted as: `Name (UUID)`
    /// e.g. `Morning Routine (A1B2C3D4-1234-5678-9ABC-DEF012345678)`
    private func parseShortcutsList(_ output: String) -> [(name: String, uuid: String)] {
        output
            .components(separatedBy: .newlines)
            .compactMap { line -> (String, String)? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return nil }
                // Expect: "Some Name (XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX)"
                guard trimmed.hasSuffix(")"),
                      let openParen = trimmed.lastIndex(of: "(") else { return nil }
                let uuidStart = trimmed.index(after: openParen)
                let uuidEnd   = trimmed.index(before: trimmed.endIndex)
                let uuid = String(trimmed[uuidStart..<uuidEnd])
                let name = trimmed[trimmed.startIndex..<openParen]
                    .trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty, !uuid.isEmpty else { return nil }
                return (name, uuid)
            }
    }

    // MARK: - Formatting

    private func printTable(_ entries: [(name: String, uuid: String)]) {
        let nameWidth = max(entries.map(\.name.count).max() ?? 0, "NAME".count)
        let uuidWidth = max(entries.map(\.uuid.count).max() ?? 0, "UUID".count)

        let header    = "NAME".padding(toLength: nameWidth, withPad: " ", startingAt: 0)
                      + "  "
                      + "UUID"
        let separator = String(repeating: "─", count: nameWidth)
                      + "  "
                      + String(repeating: "─", count: uuidWidth)

        print(header)
        print(separator)
        for (name, uuid) in entries.sorted(by: { $0.name < $1.name }) {
            let paddedName = name.padding(toLength: nameWidth, withPad: " ", startingAt: 0)
            print("\(paddedName)  \(uuid)")
        }
    }

    // MARK: - Process helper

    private func runProcess(executable: String, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError  = FileHandle.nullDevice

            process.terminationHandler = { p in
                let data   = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                if p.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: ShortcutListError.processFailed(status: p.terminationStatus))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

enum ShortcutListError: LocalizedError {
    case processFailed(status: Int32)
    var errorDescription: String? {
        switch self {
        case .processFailed(let s): return "`shortcuts list` exited with status \(s)"
        }
    }
}
