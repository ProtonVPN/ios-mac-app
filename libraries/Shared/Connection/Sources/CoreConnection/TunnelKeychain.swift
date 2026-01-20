//
//  Created on 12/01/2026 by Chris Janusiewicz.
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

import struct ConnectionShared.TunnelKeychainImplementation
import enum ConnectionShared.VPNKeychainError
import Dependencies
import Foundation

package struct TunnelKeychain: DependencyKey {
    private var storeWireguardConfig: (Data) throws -> Data
    package var loadWireguardConfig: () throws -> Data?
    package var clear: () throws -> Void

    package init(
        storeWireguardConfig: @escaping (Data) throws -> Data,
        loadWireguardConfig: @escaping () throws -> Data?,
        clear: @escaping () throws -> Void
    ) {
        self.storeWireguardConfig = storeWireguardConfig
        self.loadWireguardConfig = loadWireguardConfig
        self.clear = clear
    }

    package static let liveValue: TunnelKeychain = {
        let keychain = TunnelKeychainImplementation()

        return .init(
            storeWireguardConfig: keychain.store,
            loadWireguardConfig: keychain.loadWireguardConfig,
            clear: keychain.clear
        )
    }()
}

package extension TunnelKeychain {
    func store(wireguardConfigData data: Data) throws -> Data {
        try storeWireguardConfig(data)
    }

    func store(wireguardConfigString: String) throws -> Data {
        guard let configData = wireguardConfigString.data(using: .utf8) else {
            throw VPNKeychainError.encodingError
        }

        return try store(wireguardConfigData: configData)
    }
}

package extension DependencyValues {
    var tunnelKeychain: TunnelKeychain {
        get { self[TunnelKeychain.self] }
        set { self[TunnelKeychain.self] = newValue }
    }
}
