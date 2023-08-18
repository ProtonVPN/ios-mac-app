//
//  Created on 13/03/2023.
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

/// Persistent key value store suitable for storing large amounts of data
public struct DataStorage: TestDependencyKey {
    var storeData: (_ data: Data, _ key: String) throws -> Void
    var getData: (_ key: String) throws -> Data

    public init(
        storeData: @escaping (Data, String) throws -> Void,
        getData: @escaping (String) throws -> Data
    ) {
        self.storeData = storeData
        self.getData = getData
    }

    public static var testValue: DataStorage = {
        #if DEBUG
        let memoryStorage = MemoryStorage()
        return DataStorage(
            storeData: { (data, key) in
                memoryStorage.setValue(data, forKey: key)
            },
            getData: { key in
                guard let data = memoryStorage.getValue(forKey: key) as? Data else {
                    throw MemoryStorage.StorageError.valueNotFound
                }
                return data
            }
        )
        #else
        fatalError("No live value is set for data storage")
        #endif
    }()
}

/// Helpers for more ergonomic call site (Protocol Witness cannot define argument labels)
extension DataStorage {
    public func store(_ data: Data, forKey key: String) throws {
        try storeData(data, key)
    }
    public func getData(forKey key: String) throws -> Data {
        try getData(key)
    }
}

extension DependencyValues {
    public var dataStorage: DataStorage {
      get { self[DataStorage.self] }
      set { self[DataStorage.self] = newValue }
    }
}
