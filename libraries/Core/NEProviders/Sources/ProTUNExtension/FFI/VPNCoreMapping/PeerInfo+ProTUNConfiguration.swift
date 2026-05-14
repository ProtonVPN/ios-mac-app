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

#if DEBUG && os(iOS)

    import Foundation
    import struct VPNCoreTypes.ProTUNConfiguration

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
                priority: Int32(peer.priority)
            )
        }
    }
#endif
