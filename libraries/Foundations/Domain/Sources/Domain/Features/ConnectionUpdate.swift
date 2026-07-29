//
//  Created on 17/06/2026.
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

import Foundation
import VPNCoreTypes

/// Mirrors every field we might want to update in the `NETunnelProviderProtocol`, except everything is optional.
public struct ConnectionUpdate: Identifiable, Sendable, Equatable, Codable {
    public struct Location: Sendable, Equatable, Codable {
        public let spec: ConnectionSpec
        public let peers: [ProTUNConfiguration.Peer]

        public init(spec: ConnectionSpec, peers: [ProTUNConfiguration.Peer]) {
            self.spec = spec
            self.peers = peers
        }
    }

    public let id: UUID

    // Tunnel settings
    public var location: Location?
    public var connectionProtocol: ConnectionProtocol?
    public var killSwitch: Bool?
    public var allowLAN: Bool?
    public var customDNS: [String]?

    // LocalAgent features
    public var netShield: NetShieldType?
    public var vpnAccelerator: Bool?
    public var moderateNAT: NATType?
    public var portForwarding: Bool?

    public init(
        location: Location? = nil,
        connectionProtocol: ConnectionProtocol? = nil,
        killSwitch: Bool? = nil,
        allowLAN: Bool? = nil,
        customDNS: [String]? = nil,
        netShield: NetShieldType? = nil,
        vpnAccelerator: Bool? = nil,
        moderateNAT: NATType? = nil,
        portForwarding: Bool? = nil
    ) {
        self.id = UUID()
        self.location = location
        self.connectionProtocol = connectionProtocol
        self.killSwitch = killSwitch
        self.allowLAN = allowLAN
        self.customDNS = customDNS
        self.netShield = netShield
        self.vpnAccelerator = vpnAccelerator
        self.moderateNAT = moderateNAT
        self.portForwarding = portForwarding
    }
}

public extension ConnectionUpdate {
    static func zeroPeer(using spec: ConnectionSpec) -> Self {
        Self(
            location: .init(spec: spec, peers: []),
            killSwitch: true
        )
    }
}

public extension ConnectionUpdate {
    /// Whether this update requests any feature changes that require touching the ``ProTUNConfiguration``.
    var hasConfigurationChanges: Bool {
        location != nil || connectionProtocol != nil || hasAgentChanges || customDNS != nil
    }

    // Whether this update requires the ProTUN connection to be updated with a new set of peers
    var hasPeerChanges: Bool {
        location != nil || connectionProtocol != nil
    }

    /// Whether this update requests any Local Agent feature change (a feature that is provided by the server).
    var hasAgentChanges: Bool {
        netShield != nil || vpnAccelerator != nil || moderateNAT != nil || portForwarding != nil
    }

    var requiresReassertion: Bool {
        location != nil || connectionProtocol != nil
    }

    /// Whether this update requires network settings to be reapplied
    var requiresNetworkSettingsRefresh: Bool {
        if customDNS != nil {
            // To no ones's surprise, custom DNS servers are explicitly provided via `NETunnelNetworkSettings`,
            // so it follows that these settings must be applied by the adapter.
            true
        } else if killSwitch != nil || allowLAN != nil {
            // Give a little nudge to the extension/system to apply the correct routing table rules.
            // Without refreshing the network settings, these features do not function as expected when applied live
            // while the tunnel is already active.
            true
        } else {
            false
        }
    }
}
