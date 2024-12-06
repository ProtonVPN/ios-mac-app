//
//  Created on 06/12/2024.
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
import Dependencies
import Domain

// Improvement: Sendable conformance (requires refactor to Storage dependency)
public struct DefaultConnectionPreferenceStorage {
    private var getDefaultConnectionPreference: () throws -> DefaultConnectionPreference?
    private var setDefaultConnectionPreference: (DefaultConnectionPreference) throws -> Void

    private static let storageKeyPrefix = "DefaultConnectionPreference"

    public init(
        getDefaultConnectionPreference: @escaping () throws -> DefaultConnectionPreference?,
        setDefaultConnectionPreference: @escaping (DefaultConnectionPreference) throws -> Void
    ) {
        self.getDefaultConnectionPreference = getDefaultConnectionPreference
        self.setDefaultConnectionPreference = setDefaultConnectionPreference
    }
}

extension DefaultConnectionPreferenceStorage: DependencyKey {
    public func getPreference() throws -> DefaultConnectionPreference? {
        return try getDefaultConnectionPreference()
    }

    public func set(preference: DefaultConnectionPreference) throws {
        try setDefaultConnectionPreference(preference)
    }

    public static let liveValue: DefaultConnectionPreferenceStorage = {
        @Dependency(\.storage) var storage
        return .init(
            getDefaultConnectionPreference: { try storage.getForUser(DefaultConnectionPreference.self, forKey: storageKeyPrefix) },
            setDefaultConnectionPreference: { try storage.setForUser($0, forKey: storageKeyPrefix) }
        )
    }()
}

extension DependencyValues {
    public var defaultConnectionStorage: DefaultConnectionPreferenceStorage {
        get { self[DefaultConnectionPreferenceStorage.self] }
        set { self[DefaultConnectionPreferenceStorage.self] = newValue }
    }
}
