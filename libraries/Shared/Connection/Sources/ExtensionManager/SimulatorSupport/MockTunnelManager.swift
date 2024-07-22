//
//  Created on 31/05/2024.
//
//  Copyright (c) 2024 Proton AG
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

#if targetEnvironment(simulator)
import Foundation
import enum NetworkExtension.NEVPNStatus

import Dependencies

import ExtensionIPC
import struct Domain.ServerConnectionIntent
import struct ConnectionFoundations.LogicalServerInfo

@available(iOS 16, *)
final class MockTunnelManager: TunnelManager {

    var tunnelStartErrorToThrow: Error?
    var session: VPNSession { connection }

    var connection: VPNSessionMock

    init(connection: VPNSessionMock = .init(status: .disconnected)) {
        self.connection = connection
    }

    func startTunnel(with intent: ServerConnectionIntent) async throws {
        if let tunnelStartErrorToThrow {
            throw tunnelStartErrorToThrow
        }
        let server = intent.server
        connection.connectedServer = .init(logicalID: server.logical.id, serverID: server.endpoint.id)
        try connection.startTunnel()
    }

    func stopTunnel() async throws {
        connection.stopTunnel()
    }

    var status: NEVPNStatus {
        get async throws {
            connection.status
        }
    }

    var connectedServer: LogicalServerInfo {
        get async throws {
            connection.connectedServer
        }
    }

    var statusStream: AsyncStream<NEVPNStatus> {
        let statusChangedNotifications = NotificationCenter.default
            .notifications(named: Notification.Name.NEVPNStatusDidChange, object: connection)
            .map { _ in self.connection.status }
        return AsyncStream(statusChangedNotifications)
    }

    func removeManagers() async throws { }
}
#endif
