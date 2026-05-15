import Foundation
import GRDB
import ControlPlaneSDK

/// Persists profiles to SQLite via GRDB.
///
/// All methods are async; callers `await` them exactly as they did with the
/// previous in-memory implementation — the actor boundary and call sites are
/// unchanged.
actor ProfileStore {
    private let db: AppDatabase

    init(db: AppDatabase) {
        self.db = db
    }

    // MARK: - CRUD

    func create(name: String, parentID: UUID?, exclusive: Bool, confidenceThreshold: Double = 1.0) async throws -> Profile {
        try await assertNameAvailable(name, excludingID: nil)
        let profile = Profile(name: name, parentID: parentID, exclusive: exclusive, confidenceThreshold: confidenceThreshold)
        let record = ProfileRecord(profile)
        try await db.dbQueue.write { db in try record.insert(db) }
        log("Profile created: \(profile.id) \"\(profile.name)\"")
        return profile
    }

    func get(_ id: UUID) async throws -> Profile {
        guard let record = try await db.dbQueue.read({ db in
            try ProfileRecord.fetchOne(db, key: id.uuidString)
        }) else {
            throw CPError.profileNotFound(id)
        }
        return record.toProfile()
    }

    func update(id: UUID, name: String, parentID: UUID?, exclusive: Bool, confidenceThreshold: Double) async throws -> Profile {
        try await assertNameAvailable(name, excludingID: id)
        let existing = try await get(id)
        let updated = Profile(
            id: existing.id,
            name: name,
            parentID: parentID,
            exclusive: exclusive,
            confidenceThreshold: confidenceThreshold,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        let record = ProfileRecord(updated)
        try await db.dbQueue.write { db in
            try record.update(db)
        }
        log("Profile updated: \(id) \"\(updated.name)\"")
        return updated
    }

    func delete(_ id: UUID) async throws {
        try await db.dbQueue.write { db in
            guard try ProfileRecord.fetchOne(db, key: id.uuidString) != nil else {
                throw CPError.profileNotFound(id)
            }
            try ProfileRecord.deleteOne(db, key: id.uuidString)
        }
        log("Profile deleted: \(id)")
    }

    func findByName(_ name: String) async throws -> Profile? {
        guard let record = try await db.dbQueue.read({ db in
            try ProfileRecord
                .filter(Column("name") == name)
                .fetchOne(db)
        }) else { return nil }
        return record.toProfile()
    }

    func list() async throws -> [Profile] {
        let records = try await db.dbQueue.read { db in
            try ProfileRecord
                .order(Column("createdAt"))
                .fetchAll(db)
        }
        return records.map { $0.toProfile() }
    }

    // MARK: - Transition timestamps

    func recordActivation(_ id: UUID) async throws {
        let ts = ISO8601DateFormatter().string(from: Date())
        try await db.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE profiles SET lastActivatedAt = ? WHERE id = ?",
                arguments: [ts, id.uuidString]
            )
        }
    }

    func recordDeactivation(_ id: UUID) async throws {
        let ts = ISO8601DateFormatter().string(from: Date())
        try await db.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE profiles SET lastDeactivatedAt = ? WHERE id = ?",
                arguments: [ts, id.uuidString]
            )
        }
    }

    // MARK: - Private helpers

    private func assertNameAvailable(_ name: String, excludingID: UUID?) async throws {
        if let existing = try await findByName(name), existing.id != excludingID {
            throw CPError.invalidData("A profile named '\(name)' already exists.")
        }
    }
}

// MARK: - Record type

/// Internal GRDB record. Keeps the SDK's Profile struct free of database concerns.
private struct ProfileRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "profiles"

    var id: String
    var name: String
    var parentId: String?
    var exclusive: Bool
    var confidenceThreshold: Double
    var createdAt: String
    var updatedAt: String
    var lastActivatedAt: String?
    var lastDeactivatedAt: String?

    private static let iso = ISO8601DateFormatter()

    init(_ profile: Profile) {
        id = profile.id.uuidString
        name = profile.name
        parentId = profile.parentID?.uuidString
        exclusive = profile.exclusive
        confidenceThreshold = profile.confidenceThreshold
        createdAt = Self.iso.string(from: profile.createdAt)
        updatedAt = Self.iso.string(from: profile.updatedAt)
        lastActivatedAt   = profile.lastActivatedAt.map   { Self.iso.string(from: $0) }
        lastDeactivatedAt = profile.lastDeactivatedAt.map { Self.iso.string(from: $0) }
    }

    func toProfile() -> Profile {
        Profile(
            id: UUID(uuidString: id)!,
            name: name,
            parentID: parentId.flatMap(UUID.init(uuidString:)),
            exclusive: exclusive,
            confidenceThreshold: confidenceThreshold,
            createdAt: Self.iso.date(from: createdAt) ?? Date(),
            updatedAt: Self.iso.date(from: updatedAt) ?? Date(),
            lastActivatedAt:   lastActivatedAt.flatMap   { Self.iso.date(from: $0) },
            lastDeactivatedAt: lastDeactivatedAt.flatMap { Self.iso.date(from: $0) }
        )
    }
}
