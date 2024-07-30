//
//  Created on 30/11/2023.
//
//  Copyright (c) 2023 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

import GRDB

import Domain

/// Wrapper around `DatabaseMigrator` that registers all known `SchemaVersion`s
struct Migrator {

    static let `default` = Migrator() // A single instance is able to handle migrating to any known version

    private let migrator: DatabaseMigrator

    init() {
        var migrator = DatabaseMigrator()

#if DEBUG
        // Speed up development by nuking the database when migrations change
        // https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/migrations
        // Turn this on while working on schema changes, but don't forget to turn it off after finalising the migration.
        // Keeping this off allows us to experience migrations (during development) as real users would, as well prevent us
        // from inadvertantly making changes to the schema
        migrator.eraseDatabaseOnSchemaChange = false
#endif

        // Register migrations in the order of their declaration
        SchemaVersion.all.forEach { version in
            migrator.registerMigration(version.identifier, migrate: version.migrationBlock)
        }

        self.migrator = migrator
    }

    func containsUnknownMigrations(_ writer: DatabaseWriter) throws -> Bool {
        let containsUnknownMigrations = try writer.read { db in try migrator.hasBeenSuperseded(db) }

        if !containsUnknownMigrations {
            return false
        }

        // Our database has been migrated beyond what the app understands. Let's gather some more information.
        let appliedMigrations = try writer.read { db in try migrator.appliedMigrations(db) }

        log.error(
            "Database has unknown migrations",
            category: .persistence,
            metadata: [
                "appliedMigrations": "\(appliedMigrations)",
                "registeredMigrations": "\(migrator.migrations)"
            ]
        )

        return true
    }

    func migrate(_ writer: DatabaseWriter, upTo targetVersion: SchemaVersion) throws {
        let appliedMigrations = try writer.read { db in try migrator.appliedMigrations(db) }
        log.info(
            "Migrating database",
            category: .persistence,
            metadata: [
                "currentVersion": "\(appliedMigrations.last ?? "-")",
                "targetVersion": "\(targetVersion.identifier)"
            ]
        )

        try migrator.migrate(writer, upTo: targetVersion.identifier)
    }
}

typealias MigrationBlock = (Database) throws -> Void

/// Defines an `identifier` identifying the state of the schema at a certain point in time, along with a
/// `migrationBlock` that defines changes from the previous version.
///
/// When registering migrations that involve custom functions:
///  - Refer to the function's name using a String literal in case the function definition is ever changed
///  - Only use deterministic functions: e.g. do *NOT* create a permanent index based on a function the output of which
///  depend on the current locale
///
/// > A good migration is a migration that is never modified once it has shipped.
/// >
/// > Migrations describe the past states of the database, while the rest of the application code targets the latest one
/// > only. This difference is the reason why migrations should not depend on application types.
/// > [Migrations](https://swiftpackageindex.com/groue/grdb.swift/v6.25.0/documentation/grdb/migrations)
public struct SchemaVersion {
    let identifier: String
    let migrationBlock: MigrationBlock

    /// Order of migrations is important! Make sure new migrations are added at the end of this array.
    public static let all: [SchemaVersion] = [.v1, .v2]

    public static let latest: SchemaVersion = .all.last!
}
