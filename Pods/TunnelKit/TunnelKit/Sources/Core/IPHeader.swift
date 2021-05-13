//
//  IPHeader.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 5/12/20.
//  Copyright (c) 2021 Davide De Rosa. All rights reserved.
//
//  https://github.com/passepartoutvpn
//
//  This file is part of TunnelKit.
//
//  TunnelKit is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  TunnelKit is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with TunnelKit.  If not, see <http://www.gnu.org/licenses/>.

import Foundation

/// Helper for handling IP headers.
public struct IPHeader {
    private static let ipV4: UInt8 = 4
    
    private static let ipV6: UInt8 = 6
    
    private static let ipV4ProtocolNumber = AF_INET as NSNumber

    private static let ipV6ProtocolNumber = AF_INET6 as NSNumber

    private static let fallbackProtocolNumber = ipV4ProtocolNumber

    /**
     Returns the protocol number from the IP header of a data packet.
     
     - Parameter packet: The data to inspect.
     - Returns: A protocol number between `AF_INET` and `AF_INET6`.
     */
    public static func protocolNumber(inPacket packet: Data) -> NSNumber {
        guard !packet.isEmpty else {
            return fallbackProtocolNumber
        }

        // 'packet' contains the decrypted incoming IP packet data

        // The first 4 bits identify the IP version
        let ipVersion = (packet[0] & 0xf0) >> 4
        assert(ipVersion == ipV4 || ipVersion == ipV6)
        return (ipVersion == ipV6) ? ipV6ProtocolNumber : ipV4ProtocolNumber
    }
}
