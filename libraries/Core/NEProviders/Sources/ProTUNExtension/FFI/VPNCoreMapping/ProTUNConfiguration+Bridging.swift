//
//  Created on 27/04/2026 by Chris Janusiewicz.
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
import protun
import VPNCoreTypes

extension ProTUNConfiguration.Peer {
    /// Returns a copy of the peer, exposing only the ports for `transport`, or `nil` if the peer has no ports for it.
    /// This restricts what transports ProTUN will attempt to connect with.
    /// For Smart protocol, when ``transport`` is nil, the peer is returned unchanged.
    /// If we've chosen ``.udp``:
    ///  - we return nil if the peer doesn't define ports for this transport
    ///  - we nil out ports for the other transports
    func constrained(to transport: WireGuardTransport?) -> ProTUNConfiguration.Peer? {
        guard let transport else {
            return self
        }
        let udpPorts = transport == .udp ? udpPorts : []
        let tcpPorts = transport == .tcp ? tcpPorts : []
        let tlsPorts = transport == .tls ? tlsPorts : []
        if udpPorts.isEmpty, tcpPorts.isEmpty, tlsPorts.isEmpty {
            return nil
        }
        return ProTUNConfiguration.Peer(
            id: id,
            serverIP: serverIP,
            serverPublicKey: serverPublicKey,
            udpPorts: udpPorts,
            tcpPorts: tcpPorts,
            tlsPorts: tlsPorts,
            priority: priority,
            exitLabel: exitLabel
        )
    }
}

extension PeerInfo {
    init(from peer: ProTUNConfiguration.Peer) throws(ProTUNAdapter.Error) {
        guard let serverPublicKeyData = Data(base64Encoded: peer.serverPublicKey) else {
            throw .invalidKeys
        }
        self.init(
            peerId: peer.id,
            serverIp: peer.serverIP,
            serverPublicKey: serverPublicKeyData,
            udpPorts: peer.udpPorts,
            tcpPorts: peer.tcpPorts,
            tlsPorts: peer.tlsPorts,
            priority: Int32(peer.priority),
            exitLabel: peer.exitLabel
        )
    }
}

extension ProTUNConfiguration {
    /// Merges the ``LocalAgentSettings`` reported by ProTUN with the existing provider configuration.
    func merging(effectiveSettings settings: LocalAgentSettings) -> ProTUNConfiguration {
        with(
            netShieldLevel: settings.netshieldLevel.map(\.netShieldType.rawValue),
            vpnAccelerator: settings.splitTcp,
            portForwarding: settings.portForwarding,
            randomNat: settings.randomNat
        )
    }

    /// Whether the applied server settings differ from what this configuration requested for any
    /// user-facing Local Agent setting, and therefore need persisting so the app can observe the change.
    func localAgentSettingsDiffer(from effective: LocalAgentSettings) -> Bool {
        func differs<Value: Equatable>(_ requested: Value?, _ applied: Value?) -> Bool {
            requested != applied
        }
        return netShieldLevel != effective.netshieldLevel.map(\.netShieldType.rawValue)
            || vpnAccelerator != effective.splitTcp
            || portForwarding != effective.portForwarding
            || randomNat != effective.randomNat
    }
}
