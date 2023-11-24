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
import Dependencies

struct UserDefaultsStorage: Storage {
    @Dependency(\.defaultsProvider) var provider

    func get<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let data = provider.getDefaults().data(forKey: key) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(T?.self, from: data)
        } catch {
            log.warning(
                "Failed to decode ",
                category: .settings,
                metadata: [
                    "error": "\(error)",
                    "key": "\(key)",
                    "type": "\(type)"
                    // Omit logging value we failed to decode in case it contains sensitive information
                ]
            )
            throw error
        }
    }

    func set<T: Encodable>(_ value: T?, forKey key: String) throws {
        guard let value else {
            provider.getDefaults().setValue(nil, forKey: key)
            return
        }

        do {
            let data = try JSONEncoder().encode(value)
            provider.getDefaults().setValue(data, forKey: key)
        } catch {
            log.error(
                "Failed to encode value of type \(T.self) for key \(key)",
                category: .settings,
                metadata: [
                    "error": "\(error)",
                    "key": "\(key)",
                    "type": "\(T.self)"
                    // Omit logging value we failed to encode in case it contains sensitive information
                ]
            )
            throw error
        }
    }

    func setValue(_ value: Any?, forKey key: String) {
        provider.getDefaults().setValue(value, forKey: key)
    }

    func getValue(forKey key: String) -> Any? {
        provider.getDefaults().value(forKey: key)
    }

    func contains(_ key: String) -> Bool {
        provider.getDefaults().object(forKey: key) != nil
    }

    func removeObject(forKey key: String) {
        provider.getDefaults().removeObject(forKey: key)
    }
}

