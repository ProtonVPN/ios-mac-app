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

private enum DatabaseType {
    /// > SQLite documentation:
    /// Every :memory: database is distinct from every other. So, opening two database connections each with the filename
    /// ":memory:" will create two independent in-memory databases.
    /// [In-Memory Databases](https://www.sqlite.org/inmemorydb.html)
    case inMemory

    case physical(filePath: String)

    var path: String {
        switch self {
        case .inMemory:
            return ":memory:"

        case .physical(let filePath):
            return filePath
        }
    }
}

private func prepareDatabaseQueue(ofType type: DatabaseType) -> DatabaseQueue {
    let path = type.path
    var config = Configuration()

    config.prepareDatabase { db in
        db.add(function: bitwiseOr)
        db.add(function: bitwiseAnd)
        db.add(function: localizedCountryName)
    }

    let queue = try! DatabaseQueue(path: path, configuration: config)
    try! migrator.migrate(queue)
    return queue
}

/// We hold a lazy reference to this writer since each call to `databaseQueue(ofType: .inMemory)` creates a new
/// in-memory database
private let sharedInMemoryWriter: DatabaseWriter = {
    return prepareDatabaseQueue(ofType: .inMemory)
}()

public struct Database {
    var writer: () -> DatabaseWriter

    /// Global in-memory database for tests
    public static var sharedInMemoryInstance: Database {
        return Database(writer: { sharedInMemoryWriter })
    }

    /// Returns a new, separate in-memory database each time it is invoked. See `DatabaseType.inMemory` for more info
    public static func newInMemoryInstance() -> Database {
        let newWriter = prepareDatabaseQueue(ofType: .inMemory)
        return Database(writer: { newWriter })
    }

    public static func physical(filePath: String) -> Database {
        let writer = prepareDatabaseQueue(ofType: .physical(filePath: filePath))
        return Database(writer: { writer })
    }
}

extension Database: DependencyKey {

    /// Global in-memory database for tests
    public static var testValue: Database { sharedInMemoryInstance }

    /// Global database, persisted on-disk in the application support directory under "database.sqlite".
    ///
    /// At the moment, this is implemented for any target that links against `Persistence`. If this needs to change,
    /// e.g. if we would like to start storing the database under a different filename or location for one of our
    /// platforms, or one of our extensions requires access to it, `Database` should only conform to `TestDependencyKey`
    /// and each target should implement the `liveValue` property as required.
    ///
    /// Application Support directory was chosen according to apple guidelines (specifically for iOS, but the same is
    /// also applicable for MacOS):
    ///
    /// > iOS Storage Best Practices:
    /// The Application Support directory is a good place to store files that might be in your Documents directory but
    /// that shouldn't be seen by users. For example, a database that your app needs but that the user would never open
    /// manually.
    /// [iOS Storage Best Practices](https://developer.apple.com/videos/play/tech-talks/204?time=225)
    public static var liveValue: Database {
        let directoryURLs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let directoryURL = directoryURLs.first else {
            fatalError("Failed to initialise app DB: cannot find URL for documents directory")
        }

        if !FileManager.default.fileExists(atPath: directoryURL.relativePath) {
            try! FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        let databaseURL = directoryURL.appendingPathComponent("database.sqlite")
        return physical(filePath: databaseURL.relativePath)
    }
}

extension DependencyValues {
    public var appDB: Database {
        get { self[Database.self] }
        set { self[Database.self] = newValue }
    }
}
