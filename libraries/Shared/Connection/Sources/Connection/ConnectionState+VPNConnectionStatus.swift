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
        case let .connecting(.resolved(intent)):
            intent.spec
        case .resolving:
            nil
        case .disconnected:
            nil
        case let .connecting(.unresolved(intent)):
            intent.spec
        }
    }

    /// The active `Server`, when one is known. Includes the prior server during `.resolving`.
    var resolvedServer: Server? {
        switch self {
        case let .connected(_, connectionData):
            connectionData.currentPeer
        case .disconnecting:
            nil // If spec specifies `exact` server, we could return that
        case let .connecting(.resolved(intent)):
            intent.resolvedServer
        case .resolving:
            nil // TODO: ProTUN: check if this makes sense
        case .disconnected, .connecting(.unresolved):
            nil
        }
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

    var isConnectedOrConnecting: Bool {
        self.is(\.connected) || self.is(\.connecting)
    }

    /// Session-validation predicate: VPN tunnel is up (`.connected`) or being torn down (`.disconnecting`).
    var isConnectedForSessionValidation: Bool {
        switch self {
        case .connected, .disconnecting:
            true
        case .resolving, .disconnected, .connecting:
            false
        }
    }

    /// Properties-refresh predicate: safe to refresh remote properties because no tunnel is up or going down.
    var isDisconnectedForPropertiesRefresh: Bool {
        switch self {
        case .connected, .disconnecting:
            false
        case .resolving, .disconnected, .connecting:
            true
        }
    }

    /// App-quit predicate: safe to terminate without disconnecting (no in-flight tunnel).
    var isSafeToEnd: Bool {
        switch self {
        case .connected, .connecting, .disconnecting:
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

    /// Mapping of `ConnectionState` into the legacy `VPNConnectionStatusDoNotUse`.
    /// Used only in the widget. DO NOT USE OTHERWISE
    var status: VPNConnectionStatusDoNotUse {
        switch self {
        case .resolving:
            .resolving(nil, nil) // TODO: ProTUN: check what we can do to restore the code below somehow without associated values
//            let actual = intent.map { VPNConnectionActual(server: server ?? $0.server, intent: $0, connectedDate: nil) }
//            return .resolving(intent?.spec, actual)
//        case .disconnected:
//            .disconnected
//        case let .connecting(.unresolved(intent)):
//            .connecting(intent.spec, nil)
//        case let .connecting(.resolved(intent, server)):
//            .connecting(intent.spec, server)
//        case let .disconnecting(intent, server):
//            .disconnecting(intent.spec, VPNConnectionActual(server: server, intent: intent, connectedDate: nil))
//        case let .connected(intent, server, date, _):
//            .connected(intent.spec, VPNConnectionActual(server: server, intent: intent, connectedDate: date))

        case .disconnected:
            .disconnected

        case let .connecting(.unresolved(intent)):
            .connecting(intent.spec, nil)

        case let .connecting(.resolved(intent)):
            .connecting(intent.spec, nil)

        case let .disconnecting(_, spec):
            .disconnecting(spec, nil)

        case let .connected(tunnelConfig, _):
            .connected(tunnelConfig.connectionSpec, connectedActual)
        }
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
