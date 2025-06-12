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
    public var getDefaultProtocol: () throws -> ConnectionProtocol

    enum StorageKeys: String {
        /// Defined here
        case defaultConnection = "DefaultConnectionPreference"
        /// Also defined in PropertiesManager.Keys
        case smartProtocol
        /// Also defined in PropertiesManager.Keys
        case vpnProtocol = "VpnProtocol"
    }
}

extension DefaultConnectionPreferenceStorage {
    public static let liveValue: DefaultConnectionPreferenceStorage = {
        @Dependency(\.storage) var storage
        @Dependency(\.defaultsProvider) var defaultsProvider

        return .init(
            set: {
                try storage.setForUser($0, forKey: StorageKeys.defaultConnection.rawValue)
                WidgetCenter.shared.reloadAllTimelines()
            },
            getPreference: {
                try storage.getForUser(DefaultConnectionPreference.self, forKey: StorageKeys.defaultConnection.rawValue)
            },
            getDefaultProtocol: {
                let smartProtocol = defaultsProvider.getDefaults().bool(forKey: StorageKeys.smartProtocol.rawValue)
                let vpnProtocol = try? storage.get(VpnProtocol.self, forKey: StorageKeys.vpnProtocol.rawValue)

                if let vpnProtocol {
                    return smartProtocol ? .smartProtocol : .vpnProtocol(vpnProtocol)
                }

                return .smartProtocol
            }
        )
    }()
}

extension DependencyValues {
    public var defaultConnectionStorage: DefaultConnectionPreferenceStorage {
        get { self[DefaultConnectionPreferenceStorage.self] }
        set { self[DefaultConnectionPreferenceStorage.self] = newValue }
    }
}
