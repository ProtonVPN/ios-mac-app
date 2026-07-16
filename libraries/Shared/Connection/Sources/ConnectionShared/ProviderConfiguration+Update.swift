//
//  Created on 16/07/2026.
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
import enum VPNCoreTypes.WireGuardTransport

public extension NETunnelProviderProtocol {
    /// Applies an update to the stored configuration: the request id, the OS-enforced flags, the connection spec, and
    /// the peers, preferred transport and requested Local Agent features inside the ProTUN configuration. The app
    /// records the update into NE preferences with this transform before sending it, and the extension applies the
    /// same transform to its in-memory session configuration on receipt, so the two records can't drift.
    func apply(update: ConnectionUpdate) throws {
        requestId = update.id

        // Native NETunnelProviderProtocol configuration options go up here
        #if !os(tvOS)
            if let killSwitch = update.killSwitch {
                includeAllNetworks = killSwitch
            }

            if let allowLAN = update.allowLAN {
                excludeLocalNetworks = !allowLAN
            }
        #endif

        // If we don't have changes to make to the `ProTUNConfiguration`, don't bother unpacking it.
        guard update.hasConfigurationChanges else { return }

        try withProTUNConfiguration { protunConfig in
            if let location = update.location {
                try setConnectionSpec(location.spec)
                protunConfig = protunConfig.with(peers: location.peers)
            }

            if let newProtocol = update.connectionProtocol {
                // Pass .some(transport) to overwrite any existing preferredTransport in the config,
                // even when transport happens to be nil (reflecting app-side smart protocol)
                protunConfig = protunConfig.with(preferredTransport: .some(newProtocol.wireGuardTransport))
            }

            // Record the requested Local Agent features. The configuration always carries the user's latest request.
            protunConfig = protunConfig.with(
                netShieldLevel: update.netShield?.rawValue,
                vpnAccelerator: update.vpnAccelerator,
                portForwarding: update.portForwarding,
                randomNat: update.moderateNAT?.flag
            )
        }
    }
}

public extension Domain.ConnectionProtocol {
    var wireGuardTransport: VPNCoreTypes.WireGuardTransport? {
        if case let .vpnProtocol(.wireGuard(transport)) = self {
            switch transport {
            case .udp:
                return .udp
            case .tcp:
                return .tcp
            case .tls:
                return .tls
            }
        }
        return nil
    }
}
