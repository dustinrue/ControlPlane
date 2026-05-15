import Foundation
import GRDB
import ControlPlaneSDK

/// Persists rules to SQLite via GRDB.
actor RuleStore {
    private let db: AppDatabase

    init(db: AppDatabase) {
        self.db = db
    }

    // MARK: - CRUD

    func create(
        name: String,
        profileID: UUID,
        sensorID: String,
        readingKey: String,
        operatorID: String,
        comparand: ObservationValue,
        evaluatorID: String = "com.controlplane.evaluator.basic",
        weight: Double = 1.0,
        negate: Bool = false
    ) async throws -> Rule {
        let rule = Rule(
            name: name,
            profileID: profileID,
            sensorID: sensorID,
            readingKey: readingKey,
            operatorID: operatorID,
            comparand: comparand,
            evaluatorID: evaluatorID,
            weight: weight,
            negate: negate
        )
        let record = RuleRecord(rule)
        try await db.dbQueue.write { db in
            try record.insert(db)
        }
        log("Rule created: \(rule.id) \"\(rule.name)\"")
        return rule
    }

    func get(_ id: UUID) async throws -> Rule {
        guard let record = try await db.dbQueue.read({ db in
            try RuleRecord.fetchOne(db, key: id.uuidString)
        }) else {
            throw CPError.ruleNotFound(id)
        }
        return try record.toRule()
    }

    func update(
        id: UUID,
        name: String,
        sensorID: String,
        readingKey: String,
        operatorID: String,
        comparand: ObservationValue,
        evaluatorID: String,
        weight: Double,
        negate: Bool,
        enabled: Bool
    ) async throws -> Rule {
        let existing = try await get(id)
        let updated = Rule(
            id: existing.id,
            name: name,
            profileID: existing.profileID,
            sensorID: sensorID,
            readingKey: readingKey,
            operatorID: operatorID,
            comparand: comparand,
            evaluatorID: evaluatorID,
            weight: weight,
            negate: negate,
            enabled: enabled,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        let record = RuleRecord(updated)
        try await db.dbQueue.write { db in
            try record.update(db)
        }
        log("Rule updated: \(id) \"\(updated.name)\"")
        return updated
    }

    func delete(_ id: UUID) async throws {
        try await db.dbQueue.write { db in
            guard try RuleRecord.fetchOne(db, key: id.uuidString) != nil else {
                throw CPError.ruleNotFound(id)
            }
            try RuleRecord.deleteOne(db, key: id.uuidString)
        }
        log("Rule deleted: \(id)")
    }

    func list() async throws -> [Rule] {
        let records = try await db.dbQueue.read { db in
            try RuleRecord.order(Column("createdAt")).fetchAll(db)
        }
        return try records.map { try $0.toRule() }
    }

    func list(forProfile profileID: UUID) async throws -> [Rule] {
        let records = try await db.dbQueue.read { db in
            try RuleRecord
                .filter(Column("profileId") == profileID.uuidString)
                .order(Column("createdAt"))
                .fetchAll(db)
        }
        return try records.map { try $0.toRule() }
    }
}

// MARK: - Record type

private struct RuleRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "rules"

    var id: String
    var name: String
    var profileId: String
    var sensorId: String
    var readingKey: String
    var operatorId: String
    var comparandType: String
    var comparandValue: String
    var evaluatorId: String
    var weight: Double
    var negate: Bool
    var enabled: Bool
    var createdAt: String
    var updatedAt: String

    private static let iso = ISO8601DateFormatter()

    init(_ rule: Rule) {
        id = rule.id.uuidString
        name = rule.name
        profileId = rule.profileID.uuidString
        sensorId = rule.sensorID
        readingKey = rule.readingKey
        operatorId = rule.operatorID
        comparandType = rule.comparand.typeString
        comparandValue = rule.comparand.valueString
        evaluatorId = rule.evaluatorID
        weight = rule.weight
        negate = rule.negate
        enabled = rule.enabled
        createdAt = Self.iso.string(from: rule.createdAt)
        updatedAt = Self.iso.string(from: rule.updatedAt)
    }

    func toRule() throws -> Rule {
        let comparand = try ObservationValue(typeString: comparandType, valueString: comparandValue)
        return Rule(
            id: UUID(uuidString: id)!,
            name: name,
            profileID: UUID(uuidString: profileId)!,
            sensorID: sensorId,
            readingKey: readingKey,
            operatorID: operatorId,
            comparand: comparand,
            evaluatorID: evaluatorId,
            weight: weight,
            negate: negate,
            enabled: enabled,
            createdAt: Self.iso.date(from: createdAt) ?? Date(),
            updatedAt: Self.iso.date(from: updatedAt) ?? Date()
        )
    }
}

// MARK: - ObservationValue persistence helpers

private extension ObservationValue {
    var typeString: String {
        switch self {
        case .string:  return "string"
        case .boolean: return "boolean"
        case .number:  return "number"
        case .strings: return "strings"
        }
    }

    var valueString: String {
        switch self {
        case .string(let v):  return v
        case .boolean(let v): return v ? "true" : "false"
        case .number(let v):  return String(v)
        case .strings(let v): return v.joined(separator: "\n")
        }
    }

    init(typeString: String, valueString: String) throws {
        switch typeString {
        case "string":  self = .string(valueString)
        case "boolean": self = .boolean(valueString == "true")
        case "number":
            guard let d = Double(valueString) else {
                throw CPError.invalidData("Cannot parse number: \(valueString)")
            }
            self = .number(d)
        case "strings":
            self = .strings(valueString.isEmpty ? [] : valueString.components(separatedBy: "\n"))
        default:
            throw CPError.invalidData("Unknown ObservationValue type: \(typeString)")
        }
    }
}
