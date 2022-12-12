//
//  Created on 2022-09-30.
//
//  Copyright (c) 2022 Proton AG
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
import NetworkExtension

extension NETunnelProviderProtocol {
    static let connectedServerIdKey = "PVPNServerID"
    static let uidKey = "UID"
    static let wgProtocolKey = "wg-protocol"

    private func ensureProviderConfig() {
        guard providerConfiguration == nil else { return }

        providerConfiguration = [:]
    }

    public var connectedServerId: String? {
        get {
            providerConfiguration?[Self.connectedServerIdKey] as? String
        }
        set {
            ensureProviderConfig()
            providerConfiguration?[Self.connectedServerIdKey] = newValue
        }
    }

    public var appUid: uid_t? {
        get {
            providerConfiguration?[Self.uidKey] as? uid_t
        }
        set {
            ensureProviderConfig()
            providerConfiguration?[Self.uidKey] = newValue
        }
    }

    public var wgProtocol: String? {
        get {
            providerConfiguration?[Self.wgProtocolKey] as? String
        }
        set {
            ensureProviderConfig()
            providerConfiguration?[Self.wgProtocolKey] = newValue
        }
    }
}
