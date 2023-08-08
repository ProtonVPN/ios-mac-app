//
//  Created on 09/08/2023.
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

/// Transient `Storage` implementation suitable for unit tests
class MemoryStorage: Storage {
    var storage: [String: Any]

    init(initialValue: [String: Any] = [:]) {
        self.storage = initialValue
    }

    func get<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T? {
        return nil
    }
    func set<T: Encodable>(_ value: T, forKey key: String) throws { }

    func setValue(_ value: Any?, forKey key: String) {
        storage[key] = value
    }

    func getValue(forKey key: String) -> Any? {
        storage[key]
    }

    func contains(_ key: String) -> Bool {
        storage[key] != nil
    }

    func removeObject(forKey key: String) {
        storage[key] = nil
    }

    enum StorageError: Error {
        case valueNotFound
    }
}
