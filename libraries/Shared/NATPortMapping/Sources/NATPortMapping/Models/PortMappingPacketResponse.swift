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

public struct PortMappingPacketResponse: Sendable {
    // Header
    /// Always 0 for NAT-PMP
    let version: UInt8
    /// 128 + opcode from the request, i.e. 129 for UDP, 130 for TCP
    let opcode: UInt8
    /// 0 for success; see MappingResultCode
    let resultCode: UInt16
    /// seconds since Epoch
    let epochTime: UInt32

    // payload
    let internalPort: UInt16
    public let mappedExternalPort: UInt16
    /// Port mapping lifetime in seconds
    let mappingLifetime: UInt32

    var mappedProtocol: PortMappingProtocol {
        let protocolValue = opcode - 128
        return PortMappingProtocol(rawValue: protocolValue) ?? .udp
    }

    var mappedResultCode: MappingResultCode {
        MappingResultCode(rawValue: resultCode) ?? .unsupportedOpcode
    }

    let createDate: Date
    public var deadlineDate: Date {
        createDate.addingTimeInterval(TimeInterval(mappingLifetime))
    }

    // MARK: - Init

    init(from data: Data) throws {
        guard data.count >= 16 else {
            throw NATPortMappingError.malformedPacket
        }

        self.version = data[0]
        self.opcode = data[1]
        self.resultCode = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 2, as: UInt16.self).bigEndian }
        self.epochTime = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self).bigEndian }

        self.internalPort = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 8, as: UInt16.self).bigEndian }
        self.mappedExternalPort = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 10, as: UInt16.self).bigEndian }
        self.mappingLifetime = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 12, as: UInt32.self).bigEndian }

        self.createDate = Date()
    }
}

enum MappingResultCode: UInt16 {
    case success = 0
    case unsupportedVersion = 1 // BE will return it also for NAT-PCP request
    case notAuthorized = 2 // Not Authorized/Refused/NAT-PMP turned off
    case networkFailure = 3
    case outOfResources = 4 // BE cannot create more mappings
    case unsupportedOpcode = 5
}
