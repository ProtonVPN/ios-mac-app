//
//  Created on 16/06/2026 by Chris Janusiewicz.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Domain
import Foundation
import NetworkExtension
import VPNCoreCommon

public extension NETunnelProviderProtocol {
    private enum ProviderConfigurationKey {
        static let userID = "userID"
        static let connectionSpec = "connectionSpec"
    }

    /// The id of the user that requested this connection
    ///
    /// Stored in the `providerConfiguration` so the ProTUN extension can namespace its per-user
    /// persistent cache (keychain) storage, preventing connection credentials from being shared between
    /// accounts on the same device. `nil` for legacy-migrated configurations that predate this key.
    var userID: String? {
        get { providerConfiguration?[ProviderConfigurationKey.userID] as? String }
        set {
            guard let newValue else { return }
            setProviderConfiguration(value: newValue, forKey: ProviderConfigurationKey.userID)
        }
    }

    var connectionSpec: ConnectionSpec? {
        get throws {
            guard let data = providerConfiguration?[ProviderConfigurationKey.connectionSpec] as? Data else {
                return nil
            }
            return try JSONDecoder().decode(ConnectionSpec.self, from: data)
        }
    }

    func setConnectionSpec(_ spec: ConnectionSpec) throws {
        let data = try JSONEncoder().encode(spec)
        setProviderConfiguration(value: data, forKey: ProviderConfigurationKey.connectionSpec)
    }
}
