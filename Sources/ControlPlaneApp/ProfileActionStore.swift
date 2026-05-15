import Foundation
import GRDB
import ControlPlaneSDK

/// Persists profile action instances to SQLite via GRDB.
actor ProfileActionStore {
    private let db: AppDatabase

    init(db: AppDatabase) {
        self.db = db
    }

    // MARK: - CRUD

    func create(
        profileID: UUID,
        actionPluginID: String,
        trigger: ActionTrigger,
        config: [String: String] = [:]
    ) async throws -> ProfileAction {
        let action = ProfileAction(
            profileID: profileID,
            actionPluginID: actionPluginID,
            trigger: trigger,
            config: config
        )
        let record = try ProfileActionRecord(action)
        try await db.dbQueue.write { db in try record.insert(db) }
        log("ProfileAction created: \(action.id) [\(trigger.rawValue)] plugin=\(actionPluginID)")
        return action
    }

    func get(_ id: UUID) async throws -> ProfileAction {
        guard let record = try await db.dbQueue.read({ db in
            try ProfileActionRecord.fetchOne(db, key: id.uuidString)
        }) else {
            throw CPError.invalidData("Profile action not found: \(id)")
        }
        return try record.toProfileAction()
    }

    func update(
        id: UUID,
        actionPluginID: String,
        trigger: ActionTrigger,
        config: [String: String],
        enabled: Bool
    ) async throws -> ProfileAction {
        let existing = try await get(id)
        let updated = ProfileAction(
            id: existing.id,
            profileID: existing.profileID,
            actionPluginID: actionPluginID,
            trigger: trigger,
            config: config,
            enabled: enabled,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        let record = try ProfileActionRecord(updated)
        try await db.dbQueue.write { db in try record.update(db) }
        log("ProfileAction updated: \(id)")
        return updated
    }

    func delete(_ id: UUID) async throws {
        try await db.dbQueue.write { db in
            guard try ProfileActionRecord.fetchOne(db, key: id.uuidString) != nil else {
                throw CPError.invalidData("Profile action not found: \(id)")
            }
            try ProfileActionRecord.deleteOne(db, key: id.uuidString)
        }
        log("ProfileAction deleted: \(id)")
    }

    func list(forProfile profileID: UUID) async throws -> [ProfileAction] {
        let records = try await db.dbQueue.read { db in
            try ProfileActionRecord
                .filter(Column("profileId") == profileID.uuidString)
                .order(Column("createdAt"))
                .fetchAll(db)
        }
        return try records.map { try $0.toProfileAction() }
    }

    // MARK: - Trigger timestamp

    func recordTriggered(_ id: UUID) async throws {
        let ts = ISO8601DateFormatter().string(from: Date())
        try await db.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE profileActions SET lastTriggeredAt = ? WHERE id = ?",
                arguments: [ts, id.uuidString]
            )
        }
    }
}

// MARK: - Record

private struct ProfileActionRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "profileActions"

    var id: String
    var profileId: String
    var actionPluginId: String
    var trigger: String
    var config: String   // JSON-encoded [String: String]
    var enabled: Bool
    var createdAt: String
    var updatedAt: String
    var lastTriggeredAt: String?

    private static let iso = ISO8601DateFormatter()
    private static let jsonEncoder = JSONEncoder()
    private static let jsonDecoder = JSONDecoder()

    init(_ action: ProfileAction) throws {
        id             = action.id.uuidString
        profileId      = action.profileID.uuidString
        actionPluginId = action.actionPluginID
        trigger        = action.trigger.rawValue
        let configData = try Self.jsonEncoder.encode(action.config)
        config         = String(data: configData, encoding: .utf8) ?? "{}"
        enabled        = action.enabled
        createdAt      = Self.iso.string(from: action.createdAt)
        updatedAt      = Self.iso.string(from: action.updatedAt)
        lastTriggeredAt = action.lastTriggeredAt.map { Self.iso.string(from: $0) }
    }

    func toProfileAction() throws -> ProfileAction {
        let configData = config.data(using: .utf8) ?? Data()
        let configDict = (try? Self.jsonDecoder.decode([String: String].self, from: configData)) ?? [:]
        guard let trig = ActionTrigger(rawValue: trigger) else {
            throw CPError.invalidData("Unknown action trigger: \(trigger)")
        }
        return ProfileAction(
            id:             UUID(uuidString: id)!,
            profileID:      UUID(uuidString: profileId)!,
            actionPluginID: actionPluginId,
            trigger:        trig,
            config:         configDict,
            enabled:        enabled,
            createdAt:      Self.iso.date(from: createdAt) ?? Date(),
            updatedAt:      Self.iso.date(from: updatedAt) ?? Date(),
            lastTriggeredAt: lastTriggeredAt.flatMap { Self.iso.date(from: $0) }
        )
    }
}
