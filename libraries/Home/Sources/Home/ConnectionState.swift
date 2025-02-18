//
//  Created on 08/01/2025.
//
//  Copyright (c) 2025 Proton AG
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
import Domain
import Connection
import Dependencies
import VPNAppCore

@available(iOS 16, *)
extension InternalConnectionState {
    public func connectionStatus() throws -> VPNConnectionStatus {
        @Dependency(\.connectionIntentStorage) var storage
        switch self {
        case .unknown:
            // While we are in the unknown state, we cannot yet be sure if the tunnel is active or not,
            // So let's not even try to grab the original connection intent in case we are disconnected.
            return .resolving(nil, nil)

        case .disconnected:
            return .disconnected

        case .connecting(let server):
            let originalIntent = try storage.getConnectionIntent()
            let resolvedConnection = server.map { VPNConnectionActual(server: $0, intent: originalIntent, connectedDate: nil) }
            return .connecting(originalIntent.spec, resolvedConnection)

        case .disconnecting:
            let originalIntent = try? storage.getConnectionIntent()
            return .disconnecting(originalIntent?.spec ?? .defaultFastest, nil)

        case .connected(let server, let date, _):
            let originalIntent = try storage.getConnectionIntent()
            let resolvedConnection = VPNConnectionActual(server: server, intent: originalIntent, connectedDate: date)
            return .connected(originalIntent.spec, resolvedConnection)
        }
    }
}

extension VPNConnectionActual {
    init(server: Server, intent: ServerConnectionIntent, connectedDate: Date?) {
        self.init(
            connectedDate: connectedDate,
            vpnProtocol: .wireGuard(intent.tunnelSettings.transport),
            natType: intent.features.natType,
            safeMode: intent.features.safeMode,
            server: server
        )
    }
}
