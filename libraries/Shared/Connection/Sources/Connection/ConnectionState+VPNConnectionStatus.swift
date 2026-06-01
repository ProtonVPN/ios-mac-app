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
    /// The `ServerConnectionIntent` associated with this state, when one is known.
    /// Includes the prior intent during `.resolving`.
    var resolvedIntent: ServerConnectionIntent? {
        switch self {
        case let .connected(intent, _, _, _),
             let .disconnecting(intent, _),
             let .connecting(.resolved(intent, _)):
            intent
        case .resolving:
            nil // TODO: ProTUN, check if this makes sense
        case .disconnected, .connecting(.unresolved):
            nil
        }
    }

    /// The active `Server`, when one is known. Includes the prior server during `.resolving`.
    var resolvedServer: Server? {
        switch self {
        case let .connected(_, server, _, _),
             let .disconnecting(_, server),
             let .connecting(.resolved(_, server)):
            server
        case let .resolving:
            nil // TODO: ProTUN, check if this makes sense
        case .disconnected, .connecting(.unresolved):
            nil
        }
    }

    /// The user-intended `ConnectionSpec`, when known. Covers every case that carries a spec:
    /// connected, disconnecting, both connecting variants, and resolving when a prior intent is
    /// remembered.
    var resolvedSpec: ConnectionSpec? {
        switch self {
        case let .connecting(.unresolved(intent)):
            intent.spec
        default:
            resolvedIntent?.spec
        }
    }

    var resolvedVpnProtocol: VpnProtocol? {
        switch resolvedIntent?.protocolConfiguration {
        case .ike:
            .ike
        case let .wireGuard(settings):
            settings.transport.map(VpnProtocol.wireGuard)
        case nil:
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
        if case let .connected(_, _, date, _) = self { return date }
        return nil
    }

    var natType: NATType? {
        resolvedIntent?.features.natType
    }

    var safeMode: Bool? {
        resolvedIntent?.features.safeMode
    }

    /// The current spec's location, when known.
    var location: ConnectionSpec.Location? {
        resolvedSpec?.location
    }

    var connectedActual: VPNConnectionActual? {
        guard case let .connected(intent, server, date, _) = self else { return nil }
        return VPNConnectionActual(server: server, intent: intent, connectedDate: date)
    }

    /// Mapping of `ConnectionState` into the legacy `VPNConnectionStatusDoNotUse`.
    /// Used only in the widget. DO NOT USE OTHERWISE
    var status: VPNConnectionStatusDoNotUse {
        switch self {
        case .resolving:
            .resolving(nil, nil) // TODO: ProTUN, check what we can do to restore the code below somehow without associated values
//            let actual = intent.map { VPNConnectionActual(server: server ?? $0.server, intent: $0, connectedDate: nil) }
//            return .resolving(intent?.spec, actual)
        case .disconnected:
            .disconnected
        case let .connecting(.unresolved(intent)):
            .connecting(intent.spec, nil)
        case let .connecting(.resolved(intent, server)):
            .connecting(intent.spec, server)
        case let .disconnecting(intent, server):
            .disconnecting(intent.spec, VPNConnectionActual(server: server, intent: intent, connectedDate: nil))
        case let .connected(intent, server, date, _):
            .connected(intent.spec, VPNConnectionActual(server: server, intent: intent, connectedDate: date))
        }
    }
}

public extension VPNConnectionActual {
    init(server: Server, intent: ServerConnectionIntent, connectedDate: Date?) {
        let vpnProtocol: VpnProtocol = switch intent.protocolConfiguration {
        case .ike:
            .ike
        case let .wireGuard(wgSettings):
            .wireGuard(wgSettings.transport ?? .defaultValue)
        }
        self.init(
            connectedDate: connectedDate,
            vpnProtocol: vpnProtocol,
            natType: intent.features.natType,
            safeMode: intent.features.safeMode,
            server: server
        )
    }
}
