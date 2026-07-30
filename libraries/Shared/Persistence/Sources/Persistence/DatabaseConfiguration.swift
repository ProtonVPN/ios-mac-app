//
//  Created on 01/03/2024.
//
//  Copyright (c) 2024 Proton AG
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

import Dependencies
import Ergonomics
import Foundation
import GRDB
import Logging

/// `DatabaseConfig` defines an `executor` and `databaseType`.
///
/// The `executor` is responsible for generic logging and error handling.
///
/// The `databaseType` defines what type of database should be instantiated when a `ServerRepository` is constructed.
public struct DatabaseConfiguration: Sendable {
    public let databaseType: DatabaseType
    let executor: DatabaseExecutor
    let schemaVersion: SchemaVersion

    public init(executor: DatabaseExecutor, databaseType: DatabaseType, schemaVersion: SchemaVersion) {
        self.executor = executor
        self.databaseType = databaseType
        self.schemaVersion = schemaVersion
    }

    public static func withTestExecutor(
        databaseType: DatabaseType,
        schemaVersion: SchemaVersion = .latest
    ) -> DatabaseConfiguration {
        DatabaseConfiguration(
            executor: TestDatabaseExecutor(),
            databaseType: databaseType,
            schemaVersion: schemaVersion
        )
    }
}

// MARK: - Live configuration

public extension DatabaseConfiguration {
    /// Surfaces a database error beyond the log, typically to crash reporting.
    ///
    /// Persistence deliberately links no crash reporter, so apps inject one.
    typealias ErrorReporter = @Sendable (_ message: String, _ error: Error) -> Void

    /// Database configuration suitable for both debug and release builds.
    ///  - Database file located in the Application Support directory, or the Caches directory on tvOS
    ///  - Errors during database operations after initialisation are caught, logged and reported
    ///  - Operations resulting in an error fall back to returning default values
    ///
    /// - Parameter reportError: Invoked for errors worth surfacing beyond the log. Does nothing by default.
    static func live(reportError: @escaping ErrorReporter = { _, _ in }) -> DatabaseConfiguration {
        DatabaseConfiguration(
            executor: ErrorHandlingAndLoggingDatabaseExecutor(
                logError: { message, error in
                    log.error(
                        "\(message)",
                        category: .persistence,
                        metadata: ["error": "\(String(describing: error))"]
                    )
                    reportError(message, error)
                }
            ),
            databaseType: .liveDatabaseFile(reportError: reportError),
            schemaVersion: .latest
        )
    }
}

private extension DatabaseType {
    /// The on-disk database, falling back to an ephemeral one when its directory can't be created.
    static func liveDatabaseFile(reportError: DatabaseConfiguration.ErrorReporter) -> DatabaseType {
        let fileManager = FileManager.default

        #if os(tvOS)
            // tvOS gives apps no guaranteed persistent storage beyond the Caches directory
            let directoryURL = URL.cachesDirectory
        #else
            let directoryURL = fileManager
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first ?? URL.cachesDirectory
        #endif

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let databasePath = directoryURL
                .appendingPathComponent("database")
                .appendingPathExtension("sqlite")
                .absolutePath
            return .physical(filePath: databasePath)
        } catch {
            let message = "Failed to initialise app DB directory, falling back to ephemeral database"
            log.error("\(message)", category: .persistence, metadata: [
                "path": "\(directoryURL.absolutePath)",
                "error": "\(error)",
            ])
            assertionFailure("Failed to initialise app DB directory: \(error)")
            reportError(message, error)
            return .ephemeral
        }
    }
}

public enum DatabaseConfigurationKey: DependencyKey {
    /// Logs database errors, but reports them nowhere else.
    ///
    /// Apps that want database errors in crash reporting override this at their entry point, before anything has
    /// touched the database:
    ///
    /// ```swift
    /// prepareDependencies {
    ///     $0.databaseConfiguration = .live(reportError: SentryHelper.reportError)
    /// }
    /// ```
    public static var liveValue: DatabaseConfiguration {
        .live()
    }

    /// Configured with global/shared in-memory database
    public static var testValue: DatabaseConfiguration {
        .withTestExecutor(databaseType: .inMemory)
    }

    /// Previews get the same in-memory database as tests, so they never touch the real one on disk.
    public static var previewValue: DatabaseConfiguration {
        testValue
    }
}

public extension DependencyValues {
    var databaseConfiguration: DatabaseConfiguration {
        get { self[DatabaseConfigurationKey.self] }
        set { self[DatabaseConfigurationKey.self] = newValue }
    }
}
