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

import struct Domain.VPNServer

 final class MockTunnelManager: TunnelManager {
     var connection: MockVPNConnection

     init(connection: MockVPNConnection = .init(status: .disconnected)) {
        self.connection = connection
    }

     func startTunnel(to server: VPNServer) async throws -> VPNSession {
        try connection.startVPNTunnel()
        return connection
    }

     func stopTunnel() async throws {
        connection.status = .disconnected
    }

     func getConnection() async throws -> VPNSession {
         connection
     }

     func statusChanged() async throws -> AsyncStream<NEVPNStatus> {
         let statusChangedNotifications = NotificationCenter.default
             .notifications(named: Notification.Name.NEVPNStatusDidChange, object: connection)
             .map { _ in self.connection.status }
         return AsyncStream(statusChangedNotifications)
     }
 }
#endif
