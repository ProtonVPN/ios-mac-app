//
//  Created on 13/05/2026 by Max Kupetskyi.
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
import enum ExtensionManager.ProtocolConnectionData
import Foundation
import VPNAppCore

public extension ConnectionState {
    /// The user-intended `ConnectionSpec`, when known. Covers every case that carries a spec:
    /// connected, disconnecting, both connecting variants, and resolving when a prior intent is
    /// remembered.
    var resolvedSpec: ConnectionSpec? {
        switch self {
        case let .connected(tunnelConfig, _):
            tunnelConfig.connectionSpec
        case let .disconnecting(_, connectionSpec):
            connectionSpec
        case let .connecting(.resolved(intent), _):
            intent.spec
        case let .authenticationRequired(.resolved(intent), _):
            intent.spec
        case .resolving:
            nil
        case .disconnected:
            nil
        case let .connecting(.unresolved(intent), _):
            intent.spec
        case let .authenticationRequired(.unresolved(intent), _):
            intent.spec
        case let .killSwitchActive(spec, _):
            spec
        }
    }

    /// The active `Server`, when one is known. Includes the prior server during `.resolving`.
    var resolvedServer: Server? {
        switch self {
        case let .connected(_, connectionData):
            connectionData.currentPeer
        case .disconnecting:
            nil // If spec specifies `exact` server, we could return that
        case let .connecting(.resolved(intent), _):
            intent.resolvedServer
        case let .authenticationRequired(.resolved(intent), _):
            intent.resolvedServer
        case .resolving:
            nil // TODO: ProTUN: check if this makes sense
        case .disconnected, .connecting(.unresolved, _), .authenticationRequired(.unresolved, _), .killSwitchActive:
            nil
        }
    }

    /// Runtime data the ProTUN extension reports for the active connection, including the user's own
    /// IP and ISP as the VPN server observes them.
    ///
    /// `nil` outside of `.connected` and for IKEv2, which has no local agent. Its individual fields
    /// stay `nil` until the local agent has reported them, which happens shortly after the tunnel
    /// itself comes up.
    var proTUNConnectionData: ProtocolConnectionData.ProTUNConnectionData? {
        guard case let .connected(_, connectionData) = self else { return nil }
        return connectionData.protocolConnectionData.proTUNData
    }

    /// The address the user's traffic leaves the VPN from — the "VPN IP" the connection details and
    /// the tvOS status header show. `nil` unless connected.
    ///
    /// Prefers the exit the ProTUN local agent reports for the live session — IPv4 when the server
    /// answers with both families — falling back to the server list's exit address (offset by the
    /// endpoint's label) for IKEv2 and for the window before the agent has reported one. On Secure
    /// Core this is the exit hop rather than the entry the tunnel is dialled into, because every
    /// source here describes the exit.
    var vpnExitIP: String? {
        guard case let .connected(_, connectionData) = self else { return nil }
        let reportedExit = proTUNConnectionData.flatMap { $0.serverExitV4 ?? $0.serverExitV6 }
        return reportedExit ?? connectionData.currentPeer.endpoint.offsetExitIp
    }

    var resolvedVpnProtocol: VpnProtocol? {
        switch self {
        case let .connected(_, connectionData):
            switch connectionData.protocolConnectionData {
            case .ike:
                .ike
            case let .proTUN(proTUNConnectionData):
                .wireGuard(proTUNConnectionData.transport)
            }
        default:
            // If we adopt `StaticTunnelData`, in the connecting.resolved state, we *could* recognise IKE early
            nil
        }
    }

    var isConnected: Bool {
        self.is(\.connected)
    }

    /// Whether a tunnel interface currently holds the user's traffic. A ProTUN peer handover keeps the previous
    /// connection's interface up, so this stays true while `connecting` replaces the peer.
    var tunnelActive: Bool {
        switch self {
        case .connected, .killSwitchActive:
            true
        case let .connecting(_, tunnelActive), let .authenticationRequired(_, tunnelActive):
            tunnelActive
        case .resolving, .disconnected, .disconnecting:
            false
        }
    }

    var isConnectedOrConnecting: Bool {
        self.is(\.connected) || self.is(\.connecting) || self.is(\.authenticationRequired)
    }

    /// Session-validation predicate: VPN tunnel is up (`.connected`) or being torn down (`.disconnecting`).
    var isConnectedForSessionValidation: Bool {
        switch self {
        case .connected, .disconnecting:
            true
        case .resolving, .disconnected, .connecting, .authenticationRequired, .killSwitchActive:
            false
        }
    }

    /// Properties-refresh predicate: safe to refresh remote properties because no tunnel is up or going down.
    var isDisconnectedForPropertiesRefresh: Bool {
        switch self {
        case .connected, .disconnecting:
            false
        case .resolving, .disconnected, .connecting, .authenticationRequired, .killSwitchActive:
            true
        }
    }

    /// App-quit predicate: safe to terminate without disconnecting (no in-flight tunnel).
    var isSafeToEnd: Bool {
        switch self {
        case .connected, .connecting, .authenticationRequired, .disconnecting, .killSwitchActive:
            false
        case .resolving, .disconnected:
            true
        }
    }

    /// Date the active tunnel finished connecting. `nil` outside of `.connected`.
    var connectedDate: Date? {
        if case let .connected(_, connectionData) = self { return connectionData.connectionDate }
        return nil
    }

    var natType: NATType? {
        // TODO: ProTUN: expose current NAT type via ConnectionState or mmap
        nil
    }

    /// The current spec's location, when known.
    var location: ConnectionSpec.Location? {
        resolvedSpec?.location
    }

    var connectedActual: VPNConnectionActual? {
        guard case let .connected(_, connectionData) = self else { return nil }
        return VPNConnectionActual(data: connectionData)
    }
}

public extension VPNConnectionActual {
    init(data: ConnectionState.ResolvedDynamicConnectionData) {
        let vpnProtocol: VpnProtocol = switch data.protocolConnectionData {
        case .ike:
            .ike
        case let .proTUN(proTUNData):
            .wireGuard(proTUNData.transport)
        }

        // TODO: ProTUN: make NATType available in dynamic connection data
        self.init(
            connectedDate: data.connectionDate,
            vpnProtocol: vpnProtocol,
            natType: .moderateNAT, // spec.features.natType,
            server: data.currentPeer
        )
    }
}
