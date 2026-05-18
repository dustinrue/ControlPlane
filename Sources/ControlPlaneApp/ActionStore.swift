import Foundation
import GRDB
import ControlPlaneSDK

/// Persists the global action library (named, reusable action definitions) to SQLite.
actor ActionStore {
    private let db: AppDatabase

    init(db: AppDatabase) {
        self.db = db
    }

    // MARK: - CRUD

    func create(
        name: String,
        actionPluginID: String,
        config: [String: String] = [:]
    ) async throws -> Action {
        let action = Action(name: name, actionPluginID: actionPluginID, config: config)
        let record = try ActionRecord(action)
        try await db.dbQueue.write { db in try record.insert(db) }
        log("Action created: \(action.id) name=\(name) plugin=\(actionPluginID)", CPLogger.actions)
        return action
    }

    func get(_ id: UUID) async throws -> Action {
        guard let record = try await db.dbQueue.read({ db in
            try ActionRecord.fetchOne(db, key: id.uuidString)
        }) else {
            throw CPError.invalidData("Action not found: \(id)")
        }
        return try record.toAction()
    }

    func update(
        id: UUID,
        name: String,
        actionPluginID: String,
        config: [String: String],
        enabled: Bool
    ) async throws -> Action {
        let existing = try await get(id)
        let updated = Action(
            id: existing.id,
            name: name,
            actionPluginID: actionPluginID,
            config: config,
            enabled: enabled,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        let record = try ActionRecord(updated)
        try await db.dbQueue.write { db in try record.update(db) }
        log("Action updated: \(id) name=\(name)", CPLogger.actions)
        return updated
    }

    func delete(_ id: UUID) async throws {
        try await db.dbQueue.write { db in
            guard try ActionRecord.fetchOne(db, key: id.uuidString) != nil else {
                throw CPError.invalidData("Action not found: \(id)")
            }
            try ActionRecord.deleteOne(db, key: id.uuidString)
        }
        log("Action deleted: \(id)", CPLogger.actions)
    }

    func listAll() async throws -> [Action] {
        let records = try await db.dbQueue.read { db in
            try ActionRecord.order(Column("createdAt")).fetchAll(db)
        }
        return try records.map { try $0.toAction() }
    }
}

// MARK: - ProfileActionLinkStore

/// Persists profile ↔ action links to SQLite.
actor ProfileActionLinkStore {
    private let db: AppDatabase

    init(db: AppDatabase) {
        self.db = db
    }

    // MARK: - CRUD

    func link(profileID: UUID, actionID: UUID, trigger: ActionTrigger) async throws -> ProfileActionLink {
        let link = ProfileActionLink(profileID: profileID, actionID: actionID, trigger: trigger)
        let record = ProfileActionLinkRecord(link)
        try await db.dbQueue.write { db in try record.insert(db) }
        log("ProfileActionLink created: \(link.id) profile=\(profileID) action=\(actionID) trigger=\(trigger.rawValue)", CPLogger.actions)
        return link
    }

    func unlink(_ id: UUID) async throws {
        try await db.dbQueue.write { db in
            try ProfileActionLinkRecord.deleteOne(db, key: id.uuidString)
        }
        log("ProfileActionLink deleted: \(id)", CPLogger.actions)
    }

    func setEnabled(_ id: UUID, enabled: Bool) async throws {
        try await db.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE profileActionLinks SET enabled = ? WHERE id = ?",
                arguments: [enabled, id.uuidString]
            )
        }
    }

    func list(forProfile profileID: UUID) async throws -> [ProfileActionLink] {
        let records = try await db.dbQueue.read { db in
            try ProfileActionLinkRecord
                .filter(Column("profileId") == profileID.uuidString)
                .order(Column("createdAt"))
                .fetchAll(db)
        }
        return records.map { $0.toLink() }
    }

    func listAll() async throws -> [ProfileActionLink] {
        let records = try await db.dbQueue.read { db in
            try ProfileActionLinkRecord.order(Column("createdAt")).fetchAll(db)
        }
        return records.map { $0.toLink() }
    }

    func recordTriggered(_ id: UUID) async throws {
        let ts = ISO8601DateFormatter().string(from: Date())
        try await db.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE profileActionLinks SET lastTriggeredAt = ? WHERE id = ?",
                arguments: [ts, id.uuidString]
            )
        }
    }
}

// MARK: - GRDB Records

private struct ActionRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "actions"

    var id: String
    var name: String
    var actionPluginId: String
    var config: String   // JSON-encoded [String: String]
    var enabled: Bool
    var createdAt: String
    var updatedAt: String

    private static let iso = ISO8601DateFormatter()
    private static let jsonEncoder = JSONEncoder()
    private static let jsonDecoder = JSONDecoder()

    init(_ action: Action) throws {
        id            = action.id.uuidString
        name          = action.name
        actionPluginId = action.actionPluginID
        let configData = try Self.jsonEncoder.encode(action.config)
        config        = String(data: configData, encoding: .utf8) ?? "{}"
        enabled       = action.enabled
        createdAt     = Self.iso.string(from: action.createdAt)
        updatedAt     = Self.iso.string(from: action.updatedAt)
    }

    func toAction() throws -> Action {
        let configData = config.data(using: .utf8) ?? Data()
        let configDict = (try? Self.jsonDecoder.decode([String: String].self, from: configData)) ?? [:]
        return Action(
            id:             UUID(uuidString: id)!,
            name:           name,
            actionPluginID: actionPluginId,
            config:         configDict,
            enabled:        enabled,
            createdAt:      Self.iso.date(from: createdAt) ?? Date(),
            updatedAt:      Self.iso.date(from: updatedAt) ?? Date()
        )
    }
}

private struct ProfileActionLinkRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "profileActionLinks"

    var id: String
    var profileId: String
    var actionId: String
    var trigger: String
    var enabled: Bool
    var createdAt: String
    var lastTriggeredAt: String?

    private static let iso = ISO8601DateFormatter()

    init(_ link: ProfileActionLink) {
        id              = link.id.uuidString
        profileId       = link.profileID.uuidString
        actionId        = link.actionID.uuidString
        trigger         = link.trigger.rawValue
        enabled         = link.enabled
        createdAt       = Self.iso.string(from: link.createdAt)
        lastTriggeredAt = link.lastTriggeredAt.map { Self.iso.string(from: $0) }
    }

    func toLink() -> ProfileActionLink {
        ProfileActionLink(
            id:             UUID(uuidString: id)!,
            profileID:      UUID(uuidString: profileId)!,
            actionID:       UUID(uuidString: actionId)!,
            trigger:        ActionTrigger(rawValue: trigger) ?? .onActivate,
            enabled:        enabled,
            createdAt:      Self.iso.date(from: createdAt) ?? Date(),
            lastTriggeredAt: lastTriggeredAt.flatMap { Self.iso.date(from: $0) }
        )
    }
}
