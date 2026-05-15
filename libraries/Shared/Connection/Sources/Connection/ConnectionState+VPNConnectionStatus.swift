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
    var resolvedIntent: ServerConnectionIntent? {
        switch self {
        case let .connected(intent, _, _, _):
            intent
        case let .disconnecting(intent, _):
            intent
        case let .connecting(.resolved(intent, _)):
            intent
        case .resolving, .disconnected, .connecting(.unresolved):
            nil
        }
    }

    var resolvedServer: Server? {
        switch self {
        case let .connected(_, server, _, _):
            server
        case let .disconnecting(_, server):
            server
        case let .connecting(.resolved(_, server)):
            server
        case .resolving, .disconnected, .connecting(.unresolved):
            nil
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

    func vpnConnectionStatus(
        fallbackSpec: ConnectionSpec,
        previousStatus: VPNConnectionStatus
    ) -> VPNConnectionStatus {
        switch self {
        case .resolving:
            return .resolving(previousStatus.spec ?? fallbackSpec, previousStatus.actual)
        case .disconnected:
            return .disconnected
        case let .connecting(.unresolved(intent)):
            return .connecting(intent.spec, nil)
        case let .connecting(.resolved(intent, server)):
            return .connecting(intent.spec, server)
        case let .disconnecting(intent, server):
            return .disconnecting(intent.spec, VPNConnectionActual(server: server, intent: intent, connectedDate: nil))
        case let .connected(intent, server, date, _):
            let resolvedConnection = VPNConnectionActual(server: server, intent: intent, connectedDate: date)
            return .connected(intent.spec, resolvedConnection)
        }
    }
}

public extension VPNConnectionStatus {
    func mergedServer(using connectionState: ConnectionState) -> Server? {
        connectionState.resolvedServer ?? actual?.server ?? server
    }

    func mergedVpnProtocol(using connectionState: ConnectionState) -> VpnProtocol? {
        actual?.vpnProtocol ?? connectionState.resolvedVpnProtocol
    }

    func isConnected(using connectionState: ConnectionState) -> Bool {
        if connectionState.isConnected {
            return true
        }
        if case .connected = self {
            return true
        }
        return actual != nil
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
