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

import Ergonomics

/// `DatabaseConfig` defines an `executor` and `databaseType`.
///
/// The `executor` is responsible for generic logging and error handling.
///
/// The `databaseType` defines what type of database should be instantiated when a `ServerRepository` is constructed.
public struct DatabaseConfiguration {
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
        return DatabaseConfiguration(
            executor: TestDatabaseExecutor(),
            databaseType: databaseType,
            schemaVersion: schemaVersion
        )
    }
}

public enum DatabaseConfigurationKey: TestDependencyKey {

    /// Configured with global/shared in-memory database
    public static var testValue: DatabaseConfiguration {
        .withTestExecutor(databaseType: .inMemory)
    }
}

extension DependencyValues {
    public var databaseConfiguration: DatabaseConfiguration {
        get { self[DatabaseConfigurationKey.self] }
        set { self[DatabaseConfigurationKey.self] = newValue }
    }
}
