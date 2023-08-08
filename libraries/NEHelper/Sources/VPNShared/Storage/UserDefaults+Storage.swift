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
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            log.warning(
                "Can't decode \(type) from JSON",
                category: .settings,
                metadata: [
                    "error": "\(error)",
                    "data": "\(String(data: data, encoding: .utf8) ?? "(nil)")"
                ]
            )
        }
        // Backup for data saved in older app versions (ios: <=2.7.1, macos: <=2.2.2)
        do {
            return try PropertyListDecoder().decode(T.self, from: data)
        } catch {
            log.warning(
                "Can't decode \(type) from PropertyList",
                category: .settings,
                metadata: [
                    "error": "\(error)",
                    "data": "\(String(data: data, encoding: .utf8) ?? "(nil)")"
                ]
            )
        }
        return nil
    }

    func set<T: Encodable>(_ value: T, forKey key: String) throws where T : Encodable {
        do {
            let data = try JSONEncoder().encode(value)
            provider.getDefaults().setValue(data, forKey: key)
        } catch {
            log.error("Failed to store value for key \(key)", category: .persistence, metadata: ["error": "\(error)"])
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

