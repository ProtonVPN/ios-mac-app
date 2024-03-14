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

import Dependencies
import GRDB

/// > SQLite documentation:
/// Every :memory: database is distinct from every other. So, opening two database connections each with the filename
/// ":memory:" will create two independent in-memory databases.
/// [In-Memory Databases](https://www.sqlite.org/inmemorydb.html)
public enum DatabaseType: CustomStringConvertible {

    /// Global in-memory database shared across all `DatabaseWriter` instances initialised with this type
    case inMemory

    /// Isolated in-memory database instance
    case ephemeral

    /// Database initialised from, and persisted to, a physical file.
    ///
    /// According to apple guidelines (specifically for iOS, but the same is also applicable for MacOS), the appropriate
    /// location for such a database is the Application Support directory:
    ///
    /// > iOS Storage Best Practices:
    /// The Application Support directory is a good place to store files that might be in your Documents directory but
    /// that shouldn't be seen by users. For example, a database that your app needs but that the user would never open
    /// manually.
    /// [iOS Storage Best Practices](https://developer.apple.com/videos/play/tech-talks/204?time=225)
    case physical(filePath: String)

    public var description: String {
        switch self {
        case .inMemory:
            return "inMemory"
        case .ephemeral:
            return "ephemeral"
        case .physical(let filePath):
            return "physical(\(filePath.redactingUsername)"
        }
    }
}

extension DatabaseWriter {

    public static func from(databaseType: DatabaseType) -> DatabaseQueue {
        return prepareQueue(withDatabaseType: databaseType)
    }

    private static func createQueue(databaseType: DatabaseType, configuration: Configuration) throws -> DatabaseQueue {
        switch databaseType {
        case .inMemory:
            return try DatabaseQueue(named: "global", configuration: configuration)

        case .ephemeral:
            return try DatabaseQueue(configuration: configuration)

        case .physical(let path):
            return try DatabaseQueue(path: path, configuration: configuration)
        }
    }

    private static func prepareQueue(withDatabaseType type: DatabaseType) -> DatabaseQueue {
        var config = Configuration()

        log.info("Preparing database queue", category: .persistence, metadata: ["type": "\(type)"])

        config.prepareDatabase { db in
            db.add(function: bitwiseOr)
            db.add(function: bitwiseAnd)
            db.add(function: localizedCountryName.createFunctionForRegistration())
        }

        let queue = try! createQueue(databaseType: type, configuration: config)

        try! migrator.migrate(queue)

        return queue
    }
}
