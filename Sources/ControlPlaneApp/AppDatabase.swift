import Foundation
import GRDB
import ControlPlaneSDK

/// Owns the SQLite database connection and runs schema migrations.
///
/// The database file lives in ~/Library/Application Support/ControlPlane/
/// (or inside the sandbox container when the app is sandboxed — FileManager
/// resolves the correct path automatically in both cases).
///
/// Pass this to any store that needs database access. A single shared instance
/// is created by Backend at startup and kept alive for the process lifetime.
final class AppDatabase {
    let dbQueue: DatabaseQueue

    // MARK: - Factory

    static func openShared() throws -> AppDatabase {
        let dir = try appSupportDirectory()
        let dbURL = dir.appendingPathComponent("controlplane.db")

        var config = Configuration()
        // WAL mode: readers don't block writers and vice-versa.
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode=WAL")
            try db.execute(sql: "PRAGMA foreign_keys=ON")
        }

        let queue = try DatabaseQueue(path: dbURL.path, configuration: config)
        let appDB = AppDatabase(queue)
        try appDB.runMigrations()
        log("Database open: \(dbURL.path)")
        return appDB
    }

    // MARK: - Private init

    private init(_ queue: DatabaseQueue) {
        self.dbQueue = queue
    }

    // MARK: - Migrations

    private func runMigrations() throws {
        var migrator = DatabaseMigrator()

        // In debug builds, automatically wipe and recreate the DB if the schema
        // changes. This lets us iterate on the schema without manual cleanup.
        // Never set this in production.
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1_profiles") { db in
            try db.create(table: "profiles") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("parentId", .text)
                t.column("exclusive", .boolean).notNull().defaults(to: false)
                // Stored as ISO8601 text for readability and portability.
                t.column("createdAt", .text).notNull()
                t.column("updatedAt", .text).notNull()
            }
        }

        migrator.registerMigration("v2_rules") { db in
            try db.alter(table: "profiles") { t in
                t.add(column: "confidenceThreshold", .double).notNull().defaults(to: 1.0)
            }
            try db.create(table: "rules") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("profileId", .text).notNull()
                    .references("profiles", onDelete: .cascade)
                t.column("sensorId", .text).notNull()
                t.column("readingKey", .text).notNull()
                t.column("operatorId", .text).notNull()
                // comparand is split into type + value to allow indexed queries later.
                t.column("comparandType", .text).notNull()
                t.column("comparandValue", .text).notNull()
                t.column("evaluatorId", .text).notNull()
                    .defaults(to: "com.controlplane.evaluator.basic")
                t.column("weight", .double).notNull().defaults(to: 1.0)
                t.column("enabled", .boolean).notNull().defaults(to: true)
                t.column("createdAt", .text).notNull()
                t.column("updatedAt", .text).notNull()
            }
        }

        migrator.registerMigration("v3_profile_actions") { db in
            try db.create(table: "profileActions") { t in
                t.column("id", .text).primaryKey()
                t.column("profileId", .text).notNull()
                    .references("profiles", onDelete: .cascade)
                t.column("actionPluginId", .text).notNull()
                // "onActivate" or "onDeactivate"
                t.column("trigger", .text).notNull()
                // JSON-encoded [String: String] config dictionary
                t.column("config", .text).notNull().defaults(to: "{}")
                t.column("enabled", .boolean).notNull().defaults(to: true)
                t.column("createdAt", .text).notNull()
                t.column("updatedAt", .text).notNull()
            }
        }

        migrator.registerMigration("v4_unique_profile_names") { db in
            // SQLite can't ADD UNIQUE via ALTER TABLE; create a unique index instead.
            // The index enforces the constraint and also speeds up name lookups.
            try db.create(index: "idx_profiles_name",
                          on: "profiles",
                          columns: ["name"],
                          unique: true)
        }

        migrator.registerMigration("v5_transition_timestamps") { db in
            // Track when each profile last activated / deactivated.
            try db.alter(table: "profiles") { t in
                t.add(column: "lastActivatedAt",   .text)
                t.add(column: "lastDeactivatedAt", .text)
            }
            // Track when each action was last triggered.
            try db.alter(table: "profileActions") { t in
                t.add(column: "lastTriggeredAt", .text)
            }
        }

        migrator.registerMigration("v6_rule_negation") { db in
            // Add the negate flag to existing rules; defaults to false (no change in behaviour).
            try db.alter(table: "rules") { t in
                t.add(column: "negate", .boolean).notNull().defaults(to: false)
            }
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - Helpers

    private static func appSupportDirectory() throws -> URL {
        guard let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else {
            throw CPError.invalidData("Could not locate Application Support directory")
        }
        let dir = base.appendingPathComponent("ControlPlane")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
