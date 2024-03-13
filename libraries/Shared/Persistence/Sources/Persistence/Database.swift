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

fileprivate func databaseQueue(path: String) -> DatabaseQueue {
    var config = Configuration()

    config.prepareDatabase { db in
        db.add(function: bitwiseOr)
        db.add(function: bitwiseAnd)
        db.add(function: localizedCountryName)
        db.add(function: sortableServerName)
    }

    let queue =  try! DatabaseQueue(path: path, configuration: config)
    try! migrator.migrate(queue)
    return queue
}

fileprivate let testWriter: DatabaseWriter = {
    return databaseQueue(path: ":memory:")
}()

fileprivate let liveWriter: DatabaseWriter = {
    guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
        // We should probably just crash instead of falling back to in-memory db
        return testWriter
    }

    let databaseURL = documentsDirectory.appendingPathComponent("database.sqlite")

    return databaseQueue(path: databaseURL.relativePath)
}()

public struct Database: DependencyKey {
    var writer: () -> DatabaseWriter

    // In-memory database for tests
    public static var testValue: Database {
        return Database(writer: { testWriter })
    }

    public static var liveValue: Database {
        return Database(writer: { liveWriter })
    }
}

extension DependencyValues {
    public var appDB: Database {
        get { self[Database.self] }
        set { self[Database.self] = newValue }
    }
}
