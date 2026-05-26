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
        case let .connected(intent, _, _, _):
            intent
        case let .disconnecting(intent, _):
            intent
        case let .connecting(.resolved(intent, _)):
            intent
        case let .resolving(intent, _):
            intent
        case .disconnected, .connecting(.unresolved):
            nil
        }
    }

    /// The active `Server`, when one is known. Includes the prior server during `.resolving`.
    var resolvedServer: Server? {
        switch self {
        case let .connected(_, server, _, _):
            server
        case let .disconnecting(_, server):
            server
        case let .connecting(.resolved(_, server)):
            server
        case let .resolving(_, server):
            server
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
            .wireGuard(settings.transport)
        case nil:
            nil
        }
    }

    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
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

    /// Projection of `ConnectionState` into the legacy `VPNConnectionStatus` shape.
    /// Use this only at the widget-shadow boundary — in-process callers should consume
    /// `ConnectionState` directly.
    var status: VPNConnectionStatus {
        switch self {
        case let .resolving(intent, server):
            let actual = intent.map { VPNConnectionActual(server: server ?? $0.server, intent: $0, connectedDate: nil) }
            return .resolving(intent?.spec, actual)
        case .disconnected:
            return .disconnected
        case let .connecting(.unresolved(intent)):
            return .connecting(intent.spec, nil)
        case let .connecting(.resolved(intent, server)):
            return .connecting(intent.spec, server)
        case let .disconnecting(intent, server):
            return .disconnecting(intent.spec, VPNConnectionActual(server: server, intent: intent, connectedDate: nil))
        case let .connected(intent, server, date, _):
            return .connected(intent.spec, VPNConnectionActual(server: server, intent: intent, connectedDate: date))
        }
    }
}

public extension VPNConnectionActual {
    init(server: Server, intent: ServerConnectionIntent, connectedDate: Date?) {
        let vpnProtocol: VpnProtocol = switch intent.protocolConfiguration {
        case .ike:
            .ike
        case let .wireGuard(wgSettings):
            .wireGuard(wgSettings.transport)
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
