//
//  Created on 16/12/2025 by Chris Janusiewicz.
//
//  Copyright (c) 2025 Proton AG
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

public struct ProTUNConfiguration: Codable, Sendable {
    /// Base64 encoded string.
    /// A connection can be rekeyed with a new private key while the extension is active via IPC
    public let clientPrivateKey: String
    public let preferredTransport: WireGuardTransport?
    public let peers: [Peer]
    public let dnsServers: [String]

    public struct Peer: Codable, Sendable {
        public let id: String
        public let serverIP: String
        public let serverPublicKey: String
        public let udpPorts: [UInt16]
        public let tcpPorts: [UInt16]
        public let tlsPorts: [UInt16]
        public let priority: Int

        public init(
            id: String,
            serverIP: String,
            serverPublicKey: String,
            udpPorts: [UInt16],
            tcpPorts: [UInt16],
            tlsPorts: [UInt16],
            priority: Int
        ) {
            self.id = id
            self.serverIP = serverIP
            self.serverPublicKey = serverPublicKey
            self.udpPorts = udpPorts
            self.tcpPorts = tcpPorts
            self.tlsPorts = tlsPorts
            self.priority = priority
        }
    }

    public init(
        clientPrivateKey: String,
        preferredTransport: WireGuardTransport,
        peers: [Peer],
        dnsServers: [String]
    ) {
        self.clientPrivateKey = clientPrivateKey
        self.preferredTransport = preferredTransport
        self.peers = peers
        self.dnsServers = dnsServers
    }
}

public enum ProTUNConfigurationError: Error {
    case configurationMissing
    case loadFromKeychainFailed(Error)
    case decodingFailed(Error)
}
