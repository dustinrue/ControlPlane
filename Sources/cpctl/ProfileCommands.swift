import ArgumentParser
import Foundation
import ControlPlaneSDK

// MARK: - profiles group

struct ProfilesCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "profiles",
        abstract: "Create, read, update, and delete profiles.",
        subcommands: [
            ProfilesList.self,
            ProfilesGet.self,
            ProfilesAdd.self,
            ProfilesUpdate.self,
            ProfilesDelete.self,
            ProfilesActive.self,
        ]
    )
}

// MARK: - profiles list

struct ProfilesList: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all profiles."
    )

    @Flag(name: .long, help: "Display as a hierarchy tree.")
    var tree: Bool = false

    @Flag(name: .long, help: "Output raw JSON.")
    var json: Bool = false

    mutating func run() async throws {
        let client = XPCClient()

        // Fetch profiles and active state concurrently.
        async let profilesTask = client.listProfiles()
        async let activeTask   = client.listActiveProfiles()

        let (profiles, activeProfiles) = try await (profilesTask, activeTask)
        let activeIDs = Set(activeProfiles.map { $0.profile.id })

        if json {
            print(try prettyJSON(profiles))
            return
        }

        if profiles.isEmpty {
            print("No profiles.")
            return
        }

        if tree {
            printAsTree(profiles)
            return
        }

        print("\(col("NAME", 20))  \(col("ACTIVE", 6))  \(col("LAST ACTIVATED", 20))  \(col("LAST DEACTIVATED", 20))  ID")
        print(String(repeating: "-", count: 118))
        for p in profiles {
            let active    = activeIDs.contains(p.id) ? "✓" : "-"
            let activated = p.lastActivatedAt.map   { relativeTime($0) } ?? "-"
            let deactivated = p.lastDeactivatedAt.map { relativeTime($0) } ?? "-"
            print("\(col(p.name, 20))  \(col(active, 6))  \(col(activated, 20))  \(col(deactivated, 20))  \(p.id.uuidString)")
        }
    }
}

// MARK: - profiles get

struct ProfilesGet: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Show a single profile."
    )

    @Argument(help: "Profile UUID.")
    var id: String

    @Flag(name: .long, help: "Output raw JSON.")
    var json: Bool = false

    mutating func run() async throws {
        let p = try await XPCClient().resolveProfile(id)
        if json { print(try prettyJSON(p)) } else { print(p.formatted()) }
    }
}

// MARK: - profiles add

struct ProfilesAdd: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Create a new profile."
    )

    @Argument(help: "Display name for the profile.")
    var name: String

    @Option(name: .long, help: "UUID of the parent profile.")
    var parent: String?

    @Flag(name: .long, help: "Activating this profile deactivates sibling profiles.")
    var exclusive: Bool = false

    @Flag(name: .long, help: "Output raw JSON.")
    var json: Bool = false

    mutating func run() async throws {
        let parentID = try parent.map { try requireUUID($0) }
        let p = try await XPCClient().createProfile(name: name, parentID: parentID, exclusive: exclusive)
        if json { print(try prettyJSON(p)) } else { print("Created:"); print(p.formatted()) }
    }
}

// MARK: - profiles update

struct ProfilesUpdate: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "update",
        abstract: "Update an existing profile. Only provided flags are changed."
    )

    @Argument(help: "Profile UUID to update.")
    var id: String

    @Option(name: .long, help: "New display name.")
    var name: String?

    @Option(name: .long, help: "UUID of the new parent profile.")
    var parent: String?

    @Flag(name: .long, help: "Remove the parent association.")
    var clearParent: Bool = false

    @Flag(name: .long, help: "Set exclusive to true.")
    var exclusive: Bool = false

    @Flag(name: .long, help: "Set exclusive to false.")
    var notExclusive: Bool = false

    @Flag(name: .long, help: "Output raw JSON.")
    var json: Bool = false

    mutating func run() async throws {
        guard !(exclusive && notExclusive) else {
            throw ValidationError("--exclusive and --not-exclusive cannot both be set.")
        }
        guard !(parent != nil && clearParent) else {
            throw ValidationError("--parent and --clear-parent cannot both be set.")
        }

        let client = XPCClient()
        let current = try await client.resolveProfile(id)
        let uuid = current.id

        let newName      = name ?? current.name
        let newExclusive = exclusive ? true : notExclusive ? false : current.exclusive
        let newParent: UUID?
        if clearParent     { newParent = nil }
        else if let parent { newParent = try requireUUID(parent) }
        else               { newParent = current.parentID }

        let updated = try await client.updateProfile(
            id: uuid, name: newName, parentID: newParent, exclusive: newExclusive
        )
        if json { print(try prettyJSON(updated)) } else { print("Updated:"); print(updated.formatted()) }
    }
}

// MARK: - profiles delete

struct ProfilesDelete: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete a profile."
    )

    @Argument(help: "Profile UUID to delete.")
    var id: String

    @Flag(name: .shortAndLong, help: "Skip confirmation prompt.")
    var force: Bool = false

    mutating func run() async throws {
        let client = XPCClient()
        let profile = try await client.resolveProfile(id)

        if !force {
            print("Delete profile '\(profile.name)'? [y/N] ", terminator: "")
            let answer = readLine()?.lowercased() ?? ""
            guard answer == "y" || answer == "yes" else {
                print("Aborted.")
                return
            }
        }

        try await client.deleteProfile(id: profile.id)
        print("Deleted '\(profile.name)'")
    }
}

// MARK: - profiles active

struct ProfilesActive: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "active",
        abstract: "Show currently active profiles and their confidence scores."
    )

    @Flag(name: .long, help: "Output raw JSON.")
    var json: Bool = false

    mutating func run() async throws {
        let active = try await XPCClient().listActiveProfiles()

        if json {
            print(try prettyJSON(active))
            return
        }

        if active.isEmpty {
            print("No profiles are currently active.")
            return
        }

        print("\(col("CONFIDENCE", 12))  \(col("NAME", 24))  ID")
        print(String(repeating: "-", count: 80))
        for a in active {
            let score = String(format: "%.2f", a.confidence)
            print("\(col(score, 12))  \(col(a.profile.name, 24))  \(a.profile.id.uuidString)")
        }
    }
}

// MARK: - Tree rendering

private func printAsTree(_ profiles: [Profile]) {
    // Group by parentID. UUID? isn't Hashable directly, so we box nil as a sentinel.
    var byParent: [UUID?: [Profile]] = [:]
    for p in profiles {
        byParent[p.parentID, default: []].append(p)
    }

    func renderBranch(parentID: UUID?, prefix: String) {
        guard let children = byParent[parentID] else { return }
        let sorted = children.sorted { $0.createdAt < $1.createdAt }
        for (i, p) in sorted.enumerated() {
            let isLast = i == sorted.count - 1
            let exclusive = p.exclusive ? "  (exclusive)" : ""
            let id8 = String(p.id.uuidString.prefix(8))
            if parentID == nil {
                // Root: no connector, just the name
                print("\(p.name)  \(id8)\(exclusive)")
                renderBranch(parentID: p.id, prefix: "")
            } else {
                let connector  = isLast ? "└── " : "├── "
                let childPfx   = isLast ? "    " : "│   "
                print("\(prefix)\(connector)\(p.name)  \(id8)\(exclusive)")
                renderBranch(parentID: p.id, prefix: prefix + childPfx)
            }
        }
    }

    renderBranch(parentID: nil, prefix: "")
}

// MARK: - Shared helpers

private func requireUUID(_ string: String) throws -> UUID {
    guard let uuid = UUID(uuidString: string) else {
        throw ValidationError("'\(string)' is not a valid UUID.")
    }
    return uuid
}

private func prettyJSON<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return String(data: try encoder.encode(value), encoding: .utf8)!
}

private extension Profile {
    func formatted() -> String {
        let df = ISO8601DateFormatter()
        return """
        ID:        \(id.uuidString)
        Name:      \(name)
        Parent:    \(parentID?.uuidString ?? "-")
        Exclusive: \(exclusive ? "yes" : "no")
        Created:   \(df.string(from: createdAt))
        Updated:   \(df.string(from: updatedAt))
        """
    }
}
