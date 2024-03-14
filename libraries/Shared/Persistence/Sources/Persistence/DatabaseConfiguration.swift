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

import Foundation
import Logging

import Dependencies
import GRDB

/// `DatabaseConfig` defines an `executor` and `databaseType`.
///
/// The `executor` is responsible for generic logging and error handling.
///
/// The `databaseType` defines what type of database should be instantiated when a `ServerRepository` is constructed.
public struct DatabaseConfiguration {
    var executor: DatabaseExecutor
    var databaseType: DatabaseType

    public init(executor: DatabaseExecutor, databaseType: DatabaseType) {
        self.executor = executor
        self.databaseType = databaseType
    }

    public static func withTestExecutor(databaseType: DatabaseType) -> DatabaseConfiguration {
        return DatabaseConfiguration(executor: TestDatabaseExecutor(), databaseType: databaseType)
    }
}

private enum DatabaseConfigurationKey: DependencyKey {

    /// Configured with global/shared in-memory database
    public static var testValue: DatabaseConfiguration {
        .withTestExecutor(databaseType: .inMemory)
    }

    public static var liveValue: DatabaseConfiguration {
        let directoryURLs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let directoryURL = directoryURLs.first else {
            fatalError("Failed to initialise app DB: cannot find URL for application support directory")
        }

        if !FileManager.default.fileExists(atPath: directoryURL.absoluteString) {
            try! FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        let databasePath = directoryURL.appendingPathComponent("database.sqlite").absoluteString

        let executor = ErrorHandlingAndLoggingDatabaseExecutor(
            logError: { message, error in
                log.error("\(message)", category: .persistence, metadata: ["error": "\(String(describing: error))"])
            }
        )

        return DatabaseConfiguration(executor: executor, databaseType: .physical(filePath: databasePath))
    }
}

extension DependencyValues {
    public var databaseConfiguration: DatabaseConfiguration {
        get { self[DatabaseConfigurationKey.self] }
        set { self[DatabaseConfigurationKey.self] = newValue }
    }
}
