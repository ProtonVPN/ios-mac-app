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
public class MemoryStorage: Storage {
    public var storage: [String: Any]

    public init(initialValue: [String: Any] = [:]) {
        self.storage = initialValue
    }

    public func get<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let data = storage[key] as? Data else {
            return nil
        }
        guard let value = try? JSONDecoder().decode(type, from: data) else {
            return nil
        }
        return value
    }

    public func set<T: Encodable>(_ value: T?, forKey key: String) throws {
        guard let value else {
            storage[key] = nil
            return
        }
        storage[key] = try? JSONEncoder().encode(value)
    }

    public func setValue(_ value: Any?, forKey key: String) {
        storage[key] = value
    }

    public func getValue(forKey key: String) -> Any? {
        storage[key]
    }

    public func contains(_ key: String) -> Bool {
        storage[key] != nil
    }

    public func removeObject(forKey key: String) {
        storage[key] = nil
    }

    enum StorageError: Error {
        case valueNotFound
    }
}
