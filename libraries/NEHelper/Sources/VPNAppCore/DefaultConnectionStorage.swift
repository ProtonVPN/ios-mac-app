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
import DependenciesMacros
import WidgetKit
import Domain

// Improvement: Sendable conformance (requires refactor to Storage dependency)
@DependencyClient
public struct DefaultConnectionPreferenceStorage: DependencyKey {
    @DependencyEndpoint public var set: (_ preference: DefaultConnectionPreference) throws -> Void
    public var getPreference: () throws -> DefaultConnectionPreference?

    private static let storageKeyPrefix = "DefaultConnectionPreference"
}

extension DefaultConnectionPreferenceStorage {

    public static let liveValue: DefaultConnectionPreferenceStorage = {
        @Dependency(\.storage) var storage
        return .init(
            set: {
                try storage.setForUser($0, forKey: storageKeyPrefix)
                WidgetCenter.shared.reloadAllTimelines()
            },
            getPreference: { try storage.getForUser(DefaultConnectionPreference.self, forKey: storageKeyPrefix) }
        )
    }()
}

extension DependencyValues {
    public var defaultConnectionStorage: DefaultConnectionPreferenceStorage {
        get { self[DefaultConnectionPreferenceStorage.self] }
        set { self[DefaultConnectionPreferenceStorage.self] = newValue }
    }
}
