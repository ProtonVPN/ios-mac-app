//
//  Created on 16.08.23.
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

extension Storage {
    private var username: String? {
        @Dependency(\.authKeychain) var authKeychain

        return authKeychain.username
    }

    @discardableResult
    public func setUserValue(_ value: Any?, forKey key: String) -> Bool {
        guard let username else { return false }

        setValue(value, forKey: key + username)
        return true
    }

    public func getUserValue(forKey key: String) -> Any? {
        guard let username else { return nil }

        return getValue(forKey: key + username)
    }

    @discardableResult
    public func setForUser<T: Encodable>(_ value: T, forKey key: String) throws -> Bool {
        guard let username else { return false }

        try set(value, forKey: key + username)
        return true
    }

    public func getForUser<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let username else { return nil }

        return try get(type, forKey: key + username)
    }
}

extension UserDefaults {
    private var username: String? {
        @Dependency(\.authKeychain) var authKeychain

        return authKeychain.username
    }

    public func userObject(forKey key: String) -> Any? {
        guard let username else { return nil }

        return object(forKey: key + username)
    }

    public func userValue(forKey key: String) -> Any? {
        guard let username else { return nil }

        return value(forKey: key + username)
    }

    @discardableResult
    public func setUserValue(_ value: Any?, forKey key: String) -> Bool {
        guard let username else { return false }

        setValue(value, forKey: key + username)
        return true
    }
}
