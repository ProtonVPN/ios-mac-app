//
//  Created on 16/07/2025 by Max Kupetskyi.
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

import Foundation

enum PortMappingProtocol: UInt8 {
    case udp = 1
    case tcp = 2
}

struct PortMappingPacketRequest {
    // Header
    /// Always 0 for NAT-PMP
    let version: UInt8 = 0
    /// 1 = UDP mapping, 2 = TCP mapping
    let opcode: UInt8
    /// 0
    let reserved: UInt16 = 0

    // Port mapping specific payload
    /// Port on local machine
    let internalPort: UInt16
    /// Requested external port
    let externalPort: UInt16
    /// Requested lifetime in seconds
    let lifetime: UInt32

    // MARK: - Init

    init(
        opcode: UInt8,
        internalPort: UInt16,
        externalPort: UInt16,
        lifetime: UInt32
    ) {
        self.opcode = opcode
        self.internalPort = internalPort
        self.externalPort = externalPort
        self.lifetime = lifetime
    }

    /// Inits a PortMappingRequest packet
    /// - Parameters:
    ///   - portProtocol: .upd or .tcp
    ///   - internalPort: internal port requested for mapping
    ///   - externalPort: external port requested for mapping;  pass `0` for high-numbered "anonymous" port
    ///   - lifetime: requested lifetime in seconds; our BE will return some predefined value regardless of this parameter
    init(portProtocol: PortMappingProtocol, internalPort: UInt16, externalPort: UInt16, lifetime: UInt32 = 7200) {
        self.init(
            opcode: portProtocol.rawValue,
            internalPort: internalPort,
            externalPort: externalPort,
            lifetime: lifetime
        )
    }

    // MARK: Serialize

    func serialize() -> Data {
        var packet = Data()

        // Header
        packet.append(version)
        packet.append(opcode)
        packet.append(contentsOf: reserved.bigEndian.bytes)

        // Payload
        packet.append(contentsOf: internalPort.bigEndian.bytes)
        packet.append(contentsOf: externalPort.bigEndian.bytes)
        packet.append(contentsOf: lifetime.bigEndian.bytes)

        return packet
    }
}
