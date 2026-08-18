//
//  Created on 21/05/2026.
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

public enum LocalAgent {}

public struct CurrentPeer: Codable, Sendable, Equatable {
    public let peerID: String
    public let transport: WireGuardTransport
    public let port: UInt16
    public let serverExitV4: String?
    public let serverExitV6: String?
    public let userISP: String?
    public let userIP: String?

    public init(
        peerID: String,
        transport: WireGuardTransport,
        port: UInt16,
        serverExitV4: String?,
        serverExitV6: String?,
        userISP: String?,
        userIP: String?
    ) {
        self.peerID = peerID
        self.transport = transport
        self.port = port
        self.serverExitV4 = serverExitV4
        self.serverExitV6 = serverExitV6
        self.userISP = userISP
        self.userIP = userIP
    }
}
